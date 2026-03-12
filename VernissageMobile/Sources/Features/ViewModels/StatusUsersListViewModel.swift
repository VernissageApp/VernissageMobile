//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation
import Observation

@MainActor
@Observable
final class StatusUsersListViewModel {
    private(set) var users: [User] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    var errorMessage: String?

    private var nextMaxId: String?
    private var canLoadMore = true
    private var loadedSignature: String?

    func load(using appState: AppState, statusId: String, kind: StatusUsersListKind, forceRefresh: Bool = false) async {
        let signature = "\(statusId)|\(kind.rawValue)"
        if !forceRefresh, loadedSignature == signature {
            return
        }

        isLoading = true
        defer { isLoading = false }

        nextMaxId = nil
        canLoadMore = true

        do {
            let page = try await fetchPage(using: appState, statusId: statusId, kind: kind, maxId: nil)
            users = page.data
            nextMaxId = page.maxId
            canLoadMore = page.maxId != nil && !page.data.isEmpty
            loadedSignature = signature
            errorMessage = nil
        } catch {
            users = []
            nextMaxId = nil
            canLoadMore = false
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func loadMoreIfNeeded(using appState: AppState, statusId: String, kind: StatusUsersListKind, currentIndex: Int) async {
        guard !isLoading, !isLoadingMore, canLoadMore else {
            return
        }

        guard currentIndex == users.count - 1 else {
            return
        }

        guard let cursor = nextMaxId?.nilIfEmpty else {
            canLoadMore = false
            return
        }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await fetchPage(using: appState, statusId: statusId, kind: kind, maxId: cursor)
            appendUniqueUsers(page.data)
            nextMaxId = page.maxId
            canLoadMore = page.maxId != nil && !page.data.isEmpty
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func fetchPage(
        using appState: AppState,
        statusId: String,
        kind: StatusUsersListKind,
        maxId: String?
    ) async throws -> LinkableResult<User> {
        switch kind {
        case .boostedBy:
            return try await appState.api.statuses.fetchStatusRebloggedBy(statusId: statusId, maxId: maxId, limit: 40)
        case .favouritedBy:
            return try await appState.api.statuses.fetchStatusFavouritedBy(statusId: statusId, maxId: maxId, limit: 40)
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
