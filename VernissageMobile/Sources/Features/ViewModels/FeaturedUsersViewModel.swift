//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation
import Observation

@MainActor
@Observable
final class FeaturedUsersViewModel {
    private(set) var users: [User] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    var errorMessage: String?

    private(set) var userStatusesByKey: [String: [Status]] = [:]
    private(set) var loadingStatusesUserKeys: Set<String> = []
    private(set) var artistsRefreshToken = 0

    private var hasLoaded = false
    private var nextMaxId: String?
    private var canLoadMore = true
    private var isFetchingFirstPage = false

    func reset() {
        users = []
        isLoading = false
        isLoadingMore = false
        errorMessage = nil
        userStatusesByKey = [:]
        loadingStatusesUserKeys = []
        artistsRefreshToken += 1
        hasLoaded = false
        nextMaxId = nil
        canLoadMore = true
        isFetchingFirstPage = false
    }

    func load(using appState: AppState, forceRefresh: Bool = false) async {
        if !forceRefresh, hasLoaded {
            return
        }

        guard !isFetchingFirstPage, !isLoadingMore else {
            return
        }

        isFetchingFirstPage = true
        defer { isFetchingFirstPage = false }

        let shouldShowLoader = users.isEmpty
        if shouldShowLoader {
            isLoading = true
        }
        defer {
            if shouldShowLoader {
                isLoading = false
            }
        }

        do {
            let page = try await appState.fetchFeaturedUsers(maxId: nil)
            users = page.data
            nextMaxId = page.maxId
            canLoadMore = page.maxId != nil && !page.data.isEmpty
            userStatusesByKey = [:]
            loadingStatusesUserKeys = []
            artistsRefreshToken += 1
            hasLoaded = true
            errorMessage = nil
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            errorMessage = message
        }
    }

    func loadMoreIfNeeded(using appState: AppState, currentUser: User) async {
        guard hasLoaded, !isFetchingFirstPage, !isLoadingMore, canLoadMore else {
            return
        }

        guard currentUser.uniquenessKey == users.last?.uniquenessKey else {
            return
        }

        guard let cursor = nextMaxId?.nilIfEmpty else {
            canLoadMore = false
            return
        }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await appState.fetchFeaturedUsers(maxId: cursor)
            appendUniqueUsers(page.data)
            nextMaxId = page.maxId
            canLoadMore = page.maxId != nil && !page.data.isEmpty
            errorMessage = nil
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            errorMessage = message
        }
    }

    func loadStatusesIfNeeded(using appState: AppState, user: User) async {
        let key = user.uniquenessKey
        guard !loadingStatusesUserKeys.contains(key), userStatusesByKey[key] == nil else {
            return
        }

        guard let userName = user.userName?.trimmingPrefix("@").nilIfEmpty else {
            userStatusesByKey[key] = []
            return
        }

        loadingStatusesUserKeys.insert(key)
        defer { loadingStatusesUserKeys.remove(key) }

        do {
            let page = try await appState.fetchUserStatuses(userName: userName, maxId: nil, limit: 10)
            userStatusesByKey[key] = page.data.filter(\.hasAttachment)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            errorMessage = message
            userStatusesByKey[key] = []
        }
    }

    private func appendUniqueUsers(_ incoming: [User]) {
        guard !incoming.isEmpty else {
            return
        }

        var existingKeys = Set(users.map(\.uniquenessKey))
        let uniqueIncoming = incoming.filter { existingKeys.insert($0.uniquenessKey).inserted }
        users.append(contentsOf: uniqueIncoming)
    }
}
