//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ProfilePhotoCollectionScreen: View {
    @Environment(AppState.self) private var appState

    let kind: ProfileCollectionKind

    @State private var statuses: [Status] = []
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var nextMaxId: String?
    @State private var canLoadMore = true

    private var photoStatuses: [Status] {
        statuses.filter(\.hasAttachment)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if isLoading && photoStatuses.isEmpty {
                    ProgressView()
                        .tint(.primary)
                        .padding(.top, 4)
                } else if errorMessage != nil, photoStatuses.isEmpty {
                    EmptyView()
                } else if !isLoading && photoStatuses.isEmpty {
                    ContentUnavailableView(kind.emptyTitle,
                                           systemImage: "photo.on.rectangle.angled",
                                           description: Text(kind.emptyDescription))
                        .padding(.horizontal, 16)
                } else {
                    ForEach(photoStatuses, id: \.id) { status in
                        NavigationLink {
                            StatusDetailScreen(status: status)
                        } label: {
                            TimelinePhotoTileView(
                                status: status,
                                showsAuthorOverlay: true,
                                showsContentWarningOverlay: true,
                                showsImageCountOverlay: true
                            )
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            Task {
                                await loadMoreIfNeeded(currentStatusID: status.id)
                            }
                        }
                    }

                    if isLoadingMore {
                        ProgressView()
                            .tint(.primary)
                            .padding(.vertical, 12)
                    }
                }
            }
        }
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .onFirstAppear {
            await load(forceRefresh: true)
        }
        .refreshable {
            await load(forceRefresh: true)
        }
        .errorAlertToast($errorMessage)
    }

    @MainActor
    private func load(forceRefresh: Bool) async {
        if !forceRefresh, !statuses.isEmpty {
            return
        }

        guard !isLoadingMore else {
            return
        }

        let shouldShowLoader = statuses.isEmpty
        if shouldShowLoader {
            isLoading = true
        }
        defer {
            if shouldShowLoader {
                isLoading = false
            }
        }

        do {
            let page = try await fetchPage(maxId: nil)
            statuses = page.data
            nextMaxId = page.maxId
            canLoadMore = page.maxId != nil && !page.data.isEmpty
            errorMessage = nil
        } catch {
            if error.isCancellationLike {
                return
            }

            if shouldShowLoader {
                statuses = []
                nextMaxId = nil
                canLoadMore = false
            }

            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    @MainActor
    private func loadMoreIfNeeded(currentStatusID: String) async {
        guard !isLoading, !isLoadingMore, canLoadMore else {
            return
        }

        guard currentStatusID == photoStatuses.last?.id else {
            return
        }

        guard let cursor = nextMaxId?.nilIfEmpty else {
            canLoadMore = false
            return
        }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await fetchPage(maxId: cursor)
            appendUniqueStatuses(page.data)
            nextMaxId = page.maxId
            canLoadMore = page.maxId != nil && !page.data.isEmpty
            errorMessage = nil
        } catch {
            if error.isCancellationLike {
                return
            }

            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func fetchPage(maxId: String?) async throws -> LinkableResult<Status> {
        switch kind {
        case .favourites:
            return try await appState.fetchFavourites(maxId: maxId)
        case .bookmarks:
            return try await appState.fetchBookmarks(maxId: maxId)
        }
    }

    private func appendUniqueStatuses(_ incoming: [Status]) {
        guard !incoming.isEmpty else {
            return
        }

        let existingIds = Set(statuses.map(\.id))
        let uniqueIncoming = incoming.filter { !existingIds.contains($0.id) }
        statuses.append(contentsOf: uniqueIncoming)
    }
}
