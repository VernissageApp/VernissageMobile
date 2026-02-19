//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

final class NotificationsViewModel: ObservableObject {
    @Published private(set) var notifications: [AppNotification] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published var errorMessage: String?

    private var nextMaxId: String?
    private var canLoadMore = true

    @MainActor
    func load(using appState: AppState) async {
        isLoading = true
        defer { isLoading = false }

        nextMaxId = nil
        canLoadMore = true

        do {
            let page = try await appState.fetchNotifications(maxId: nil)
            notifications = page.data
            nextMaxId = page.maxId
            canLoadMore = page.maxId != nil && !page.data.isEmpty
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    @MainActor
    func loadMoreIfNeeded(using appState: AppState, currentIndex: Int) async {
        guard !isLoading, !isLoadingMore, canLoadMore else {
            return
        }

        guard currentIndex == notifications.count - 1 else {
            return
        }

        guard let cursor = nextMaxId?.nilIfEmpty else {
            canLoadMore = false
            return
        }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await appState.fetchNotifications(maxId: cursor)
            appendUniqueNotifications(page.data)
            nextMaxId = page.maxId
            canLoadMore = page.maxId != nil && !page.data.isEmpty
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func appendUniqueNotifications(_ incoming: [AppNotification]) {
        guard !incoming.isEmpty else {
            return
        }

        var existingKeys = Set(notifications.map(\.uniquenessKey))
        let uniqueIncoming = incoming.filter { existingKeys.insert($0.uniquenessKey).inserted }
        notifications.append(contentsOf: uniqueIncoming)
    }
}
