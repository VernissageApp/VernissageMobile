//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation
import Nuke
import Observation

@MainActor
@Observable
final class ExploreViewModel {
    private(set) var itemsBySelection: [ExploreContentSelection: [ExploreItem]] = [:]
    private(set) var statusesBySelection: [ExploreContentSelection: [String: [Status]]] = [:]
    private(set) var loadingSelections: Set<ExploreContentSelection> = []
    private(set) var failedSelections: Set<ExploreContentSelection> = []
    private(set) var loadingItemKeys: Set<String> = []
    private(set) var refreshTokens: [ExploreContentSelection: Int] = [:]
    var errorMessage: String?

    private var loadedSelections: Set<ExploreContentSelection> = []
    private var allCategories: [ExploreItem] = []
    private var hasLoadedAllCategories = false
    private var generation = 0
    private var requestVersions: [ExploreContentSelection: Int] = [:]
    private let imagePrefetcher = ImagePrefetcher(destination: .diskCache)

    func reset() {
        generation += 1
        itemsBySelection = [:]
        statusesBySelection = [:]
        loadingSelections = []
        failedSelections = []
        loadingItemKeys = []
        refreshTokens = [:]
        errorMessage = nil
        loadedSelections = []
        allCategories = []
        hasLoadedAllCategories = false
        requestVersions = [:]
    }

    func items(for selection: ExploreContentSelection) -> [ExploreItem] {
        itemsBySelection[selection] ?? []
    }

    func statuses(for item: ExploreItem, selection: ExploreContentSelection) -> [Status]? {
        statusesBySelection[selection]?[item.id]
    }

    func isLoading(_ selection: ExploreContentSelection) -> Bool {
        loadingSelections.contains(selection)
    }

    func didFail(_ selection: ExploreContentSelection) -> Bool {
        failedSelections.contains(selection)
    }

    func isLoadingStatuses(for item: ExploreItem, selection: ExploreContentSelection) -> Bool {
        loadingItemKeys.contains(itemKey(for: item, selection: selection))
    }

    func refreshToken(for selection: ExploreContentSelection) -> Int {
        refreshTokens[selection, default: 0]
    }

    func loadIfNeeded(
        selection: ExploreContentSelection,
        query: String,
        using appState: AppState
    ) async {
        guard !loadedSelections.contains(selection) else {
            return
        }

        await fetchAndReplaceItems(
            selection: selection,
            query: query,
            refreshCategories: false,
            using: appState
        )
    }

    func search(
        selection: ExploreContentSelection,
        query: String,
        using appState: AppState
    ) async {
        if selection == .categories, hasLoadedAllCategories {
            requestVersions[selection, default: 0] += 1
            loadingSelections.remove(selection)
            applyCategoryFilter(query: query)
            return
        }

        await fetchAndReplaceItems(
            selection: selection,
            query: query,
            refreshCategories: false,
            using: appState
        )
    }

    func refresh(
        selection: ExploreContentSelection,
        query: String,
        using appState: AppState
    ) async {
        await fetchAndReplaceItems(
            selection: selection,
            query: query,
            refreshCategories: selection == .categories,
            using: appState
        )
    }

    func loadStatusesIfNeeded(
        for item: ExploreItem,
        selection: ExploreContentSelection,
        using appState: AppState
    ) async {
        let loadingKey = itemKey(for: item, selection: selection)
        guard !loadingItemKeys.contains(loadingKey), statusesBySelection[selection]?[item.id] == nil else {
            return
        }

        let requestGeneration = generation
        loadingItemKeys.insert(loadingKey)
        defer {
            if requestGeneration == generation {
                loadingItemKeys.remove(loadingKey)
            }
        }

        do {
            let page = try await fetchStatuses(for: item, selection: selection, using: appState)
            guard requestGeneration == generation else {
                return
            }

            let photoStatuses = page.data.filter(\.hasAttachment)
            statusesBySelection[selection, default: [:]][item.id] = photoStatuses
            prefetch(statuses: photoStatuses)
        } catch {
            if error.isCancellationLike || requestGeneration != generation {
                return
            }

            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            statusesBySelection[selection, default: [:]][item.id] = []
        }
    }

    private func fetchAndReplaceItems(
        selection: ExploreContentSelection,
        query: String,
        refreshCategories: Bool,
        using appState: AppState
    ) async {
        let requestGeneration = generation
        let requestVersion = requestVersions[selection, default: 0] + 1
        requestVersions[selection] = requestVersion
        loadingSelections.insert(selection)
        defer {
            if requestGeneration == generation, requestVersions[selection] == requestVersion {
                loadingSelections.remove(selection)
            }
        }

        do {
            let result = try await fetchItems(
                selection: selection,
                query: query,
                refreshCategories: refreshCategories,
                using: appState
            )
            guard requestGeneration == generation, requestVersions[selection] == requestVersion else {
                return
            }

            if let fetchedCategories = result.fetchedCategories {
                allCategories = fetchedCategories
                hasLoadedAllCategories = true
            }

            replaceItems(result.items, for: selection)
            failedSelections.remove(selection)
            errorMessage = nil
        } catch {
            if error.isCancellationLike
                || requestGeneration != generation
                || requestVersions[selection] != requestVersion {
                return
            }

            failedSelections.insert(selection)
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func fetchItems(
        selection: ExploreContentSelection,
        query: String,
        refreshCategories: Bool,
        using appState: AppState
    ) async throws -> (items: [ExploreItem], fetchedCategories: [ExploreItem]?) {
        let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        switch selection {
        case .categories:
            let categories: [ExploreItem]
            let fetchedCategories: [ExploreItem]?

            if refreshCategories || !hasLoadedAllCategories {
                let fetched = try await appState.api.categories.fetchAll(onlyUsed: true)
                categories = fetched
                fetchedCategories = fetched
            } else {
                categories = allCategories
                fetchedCategories = nil
            }

            let items = if cleanedQuery.isEmpty {
                categories
            } else {
                categories.filter { $0.name.localizedStandardContains(cleanedQuery) }
            }

            return (items, fetchedCategories)
        case .cameras:
            let page = try await appState.api.cameras.fetch(
                query: cleanedQuery,
                page: 1,
                size: AppConstants.Explore.listPageSize
            )
            return (page.data ?? [], nil)
        case .lenses:
            let page = try await appState.api.lenses.fetch(
                query: cleanedQuery,
                page: 1,
                size: AppConstants.Explore.listPageSize
            )
            return (page.data ?? [], nil)
        case .films:
            let page = try await appState.api.films.fetch(
                query: cleanedQuery,
                page: 1,
                size: AppConstants.Explore.listPageSize
            )
            return (page.data ?? [], nil)
        }
    }

    private func fetchStatuses(
        for item: ExploreItem,
        selection: ExploreContentSelection,
        using appState: AppState
    ) async throws -> LinkableResult<Status> {
        switch selection {
        case .categories:
            try await appState.api.timelines.fetchCategoryStatuses(
                category: item.name,
                maxId: nil,
                limit: AppConstants.Explore.statusesLimit
            )
        case .cameras:
            try await appState.api.timelines.fetchCameraStatuses(
                camera: item.name,
                maxId: nil,
                limit: AppConstants.Explore.statusesLimit
            )
        case .lenses:
            try await appState.api.timelines.fetchLensStatuses(
                lens: item.name,
                maxId: nil,
                limit: AppConstants.Explore.statusesLimit
            )
        case .films:
            try await appState.api.timelines.fetchFilmStatuses(
                film: item.name,
                maxId: nil,
                limit: AppConstants.Explore.statusesLimit
            )
        }
    }

    private func applyCategoryFilter(query: String) {
        let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let items = if cleanedQuery.isEmpty {
            allCategories
        } else {
            allCategories.filter { $0.name.localizedStandardContains(cleanedQuery) }
        }

        replaceItems(items, for: .categories)
    }

    private func replaceItems(_ items: [ExploreItem], for selection: ExploreContentSelection) {
        itemsBySelection[selection] = items
        statusesBySelection[selection] = [:]
        loadedSelections.insert(selection)
        refreshTokens[selection, default: 0] += 1
    }

    private func itemKey(for item: ExploreItem, selection: ExploreContentSelection) -> String {
        "\(selection.rawValue):\(item.id)"
    }

    private func prefetch(statuses: [Status]) {
        let imageURLs = statuses.allPrefetchImageURLs
        guard !imageURLs.isEmpty else {
            return
        }

        imagePrefetcher.startPrefetching(with: imageURLs)
    }
}
