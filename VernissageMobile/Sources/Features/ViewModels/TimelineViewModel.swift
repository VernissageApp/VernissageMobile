//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

final class TimelineViewModel: ObservableObject {
    @Published private(set) var statuses: [Status] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published var errorMessage: String?

    var photoStatuses: [Status] {
        statuses.filter(\.hasAttachment)
    }

    private let kind: TimelineKind
    private var nextMaxId: String?
    private var canLoadMore = true
    private var isFetchingFirstPage = false

    init(kind: TimelineKind) {
        self.kind = kind
    }

    @MainActor
    func load(using appState: AppState, forceRefresh: Bool = false) async {
        guard !isFetchingFirstPage, !isLoadingMore else {
            return
        }

        isFetchingFirstPage = true
        defer { isFetchingFirstPage = false }

        let shouldShowInitialLoader = statuses.isEmpty && !forceRefresh
        if shouldShowInitialLoader {
            isLoading = true
        }
        defer {
            if shouldShowInitialLoader {
                isLoading = false
            }
        }

        do {
            let cachePolicy: URLRequest.CachePolicy = forceRefresh
            ? .reloadIgnoringLocalCacheData
            : .useProtocolCachePolicy
            let requestNonce = forceRefresh ? String(Int(Date().timeIntervalSince1970 * 1000)) : nil

            let page = try await appState.fetchTimeline(
                kind: kind,
                maxId: nil,
                cachePolicy: cachePolicy,
                requestNonce: requestNonce
            )
            statuses = page.data
            nextMaxId = page.maxId
            canLoadMore = page.maxId != nil && !page.data.isEmpty
            errorMessage = nil
        } catch {
            if error.isCancellationLike {
                return
            }

            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            errorMessage = message
        }
    }

    @MainActor
    func loadMoreIfNeeded(using appState: AppState, currentStatusID: String) async {
        guard !isFetchingFirstPage, !isLoadingMore, canLoadMore else {
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
            let page = try await appState.fetchTimeline(kind: kind, maxId: cursor)
            appendUniqueStatuses(page.data)
            nextMaxId = page.maxId
            canLoadMore = page.maxId != nil && !page.data.isEmpty
            errorMessage = nil
        } catch {
            if error.isCancellationLike {
                return
            }

            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            errorMessage = message
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
