//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation
import Observation
import Nuke

@MainActor
@Observable
final class TimelineViewModel {
    private(set) var statuses: [Status] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    var errorMessage: String?

    var photoStatuses: [Status] {
        statuses.filter(\.hasAttachment)
    }

    private let kind: TimelineKind
    private let imagePrefetcher = ImagePrefetcher(destination: .diskCache)
    private var nextMaxId: String?
    private var canLoadMore = true
    private var isFetchingFirstPage = false

    init(kind: TimelineKind) {
        self.kind = kind
    }

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
            let page = try await appState.api.timelines.fetchTimeline(
                kind: kind,
                maxId: nil
            )
            statuses = page.data
            prefetch(statuses: page.data)
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
            let page = try await appState.api.timelines.fetchTimeline(kind: kind, maxId: cursor)
            let uniqueStatuses = appendUniqueStatuses(page.data)
            prefetch(statuses: uniqueStatuses)
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

    private func appendUniqueStatuses(_ incoming: [Status]) -> [Status] {
        guard !incoming.isEmpty else {
            return []
        }

        let existingIds = Set(statuses.map(\.id))
        let uniqueIncoming = incoming.filter { !existingIds.contains($0.id) }
        statuses.append(contentsOf: uniqueIncoming)
        return uniqueIncoming
    }

    private func prefetch(statuses: [Status]) {
        let imageURLs = statuses.allPrefetchImageURLs
        guard !imageURLs.isEmpty else {
            return
        }

        imagePrefetcher.startPrefetching(with: imageURLs)
    }
}
