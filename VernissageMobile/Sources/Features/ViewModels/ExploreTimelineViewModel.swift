//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation
import Observation

@MainActor
@Observable
final class ExploreTimelineViewModel {
    private(set) var statuses: [Status] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    var errorMessage: String?

    var photoStatuses: [Status] {
        statuses.filter(\.hasAttachment)
    }

    private let item: ExploreItem
    private let selection: ExploreContentSelection
    private var nextMaxId: String?
    private var canLoadMore = true
    private var isFetchingFirstPage = false

    init(item: ExploreItem, selection: ExploreContentSelection) {
        self.item = item
        self.selection = selection
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
            let page = try await fetchStatuses(maxId: nil, using: appState)
            try Task.checkCancellation()

            statuses = page.data
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
            let page = try await fetchStatuses(maxId: cursor, using: appState)
            try Task.checkCancellation()

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

    private func fetchStatuses(maxId: String?, using appState: AppState) async throws -> LinkableResult<Status> {
        switch selection {
        case .categories:
            try await appState.api.timelines.fetchCategoryStatuses(
                category: item.name,
                maxId: maxId,
                limit: AppConstants.Explore.timelinePageSize
            )
        case .cameras:
            try await appState.api.timelines.fetchCameraStatuses(
                camera: item.name,
                maxId: maxId,
                limit: AppConstants.Explore.timelinePageSize
            )
        case .lenses:
            try await appState.api.timelines.fetchLensStatuses(
                lens: item.name,
                maxId: maxId,
                limit: AppConstants.Explore.timelinePageSize
            )
        case .films:
            try await appState.api.timelines.fetchFilmStatuses(
                film: item.name,
                maxId: maxId,
                limit: AppConstants.Explore.timelinePageSize
            )
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
