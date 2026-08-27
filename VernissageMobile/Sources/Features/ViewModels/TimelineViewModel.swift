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
    private(set) var caughtUpMarkerStatusID: String?
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

    private var markerTimeline: TimelineMarkerTimeline? {
        switch kind {
        case .privateHome:
            .private
        case .local:
            .local
        case .editorsChoice:
            .featured
        case .global:
            .federated
        case .trending:
            nil
        }
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
            async let previousMarkerStatusID = fetchPreviousMarkerStatusID(using: appState)
            let page = try await appState.api.timelines.fetchTimeline(
                kind: kind,
                maxId: nil
            )
            let markerStatusID = await previousMarkerStatusID
            let latestPhotoStatusID = page.data.first(where: \.hasAttachment)?.id

            statuses = page.data
            caughtUpMarkerStatusID = markerStatusID == latestPhotoStatusID ? nil : markerStatusID
            prefetch(statuses: page.data)
            nextMaxId = page.maxId
            canLoadMore = page.maxId != nil && !page.data.isEmpty
            errorMessage = nil

            await updateMarkerIfNeeded(using: appState, statusID: latestPhotoStatusID)
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

    private func fetchPreviousMarkerStatusID(using appState: AppState) async -> String? {
        guard let markerTimeline else {
            return nil
        }

        do {
            return try await TimelineMarkersAPI(appState: appState)
                .fetchMarker(for: markerTimeline)?
                .statusId
        } catch {
            return nil
        }
    }

    private func updateMarkerIfNeeded(using appState: AppState, statusID: String?) async {
        guard !Task.isCancelled,
              let markerTimeline,
              let statusID else {
            return
        }

        do {
            try await TimelineMarkersAPI(appState: appState).updateMarker(
                for: markerTimeline,
                statusId: statusID
            )
        } catch {
            // Marker synchronization is best-effort and must not prevent the timeline from loading.
        }
    }
}
