//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation
import Observation

@MainActor
@Observable
final class NotificationsViewModel {
    private(set) var notifications: [AppNotification] = []
    private(set) var notificationItems: [NotificationListItem] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    var errorMessage: String?

    private var nextMaxId: String?
    private var canLoadMore = true
    private var isFetchingFirstPage = false

    func load(using appState: AppState) async -> Bool {
        guard !isFetchingFirstPage, !isLoadingMore else {
            return false
        }

        isFetchingFirstPage = true
        defer { isFetchingFirstPage = false }

        let shouldShowInitialLoader = notifications.isEmpty
        if shouldShowInitialLoader {
            isLoading = true
        }
        defer {
            if shouldShowInitialLoader {
                isLoading = false
            }
        }

        do {
            let page = try await appState.api.notifications.fetchNotifications(maxId: nil)
            notifications = page.data
            notificationItems = makeNotificationItems(from: page.data)
            nextMaxId = page.maxId
            canLoadMore = page.maxId != nil && !page.data.isEmpty
            errorMessage = nil
            return true
        } catch {
            if error.isCancellationLike {
                return false
            }

            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    func loadMoreIfNeeded(using appState: AppState, currentIndex: Int) async {
        guard !isFetchingFirstPage, !isLoadingMore, canLoadMore else {
            return
        }

        guard currentIndex == notificationItems.count - 1 else {
            return
        }

        guard let cursor = nextMaxId?.nilIfEmpty else {
            canLoadMore = false
            return
        }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await appState.api.notifications.fetchNotifications(maxId: cursor)
            let uniqueIncoming = appendUniqueNotifications(page.data)
            notificationItems.append(contentsOf: makeNotificationItems(from: uniqueIncoming))
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

    private func appendUniqueNotifications(_ incoming: [AppNotification]) -> [AppNotification] {
        guard !incoming.isEmpty else {
            return []
        }

        var existingKeys = Set(notifications.map(\.uniquenessKey))
        let uniqueIncoming = incoming.filter { existingKeys.insert($0.uniquenessKey).inserted }
        notifications.append(contentsOf: uniqueIncoming)
        return uniqueIncoming
    }

    private func makeNotificationItems(from pageNotifications: [AppNotification]) -> [NotificationListItem] {
        var groupsByKey: [String: [AppNotification]] = [:]
        var emittedGroupKeys = Set<String>()

        for notification in pageNotifications {
            guard let groupingKey = groupingKey(for: notification) else {
                continue
            }

            groupsByKey[groupingKey, default: []].append(notification)
        }

        return pageNotifications.compactMap { notification in
            guard let groupingKey = groupingKey(for: notification),
                  let groupedNotifications = groupsByKey[groupingKey],
                  groupedNotifications.count > 1 else {
                return .notification(notification)
            }

            guard emittedGroupKeys.insert(groupingKey).inserted else {
                return nil
            }

            return .group(NotificationGroup(notifications: groupedNotifications))
        }
    }

    private func groupingKey(for notification: AppNotification) -> String? {
        guard let notificationType = notification.typedNotificationType else {
            return nil
        }

        switch notificationType {
        case .follow:
            return notificationType.rawValue
        case .favourite, .reblog:
            guard let linkedStatusId = notification.linkedStatus?.id.nilIfEmpty else {
                return nil
            }

            return "\(notificationType.rawValue)|\(linkedStatusId)|\(notification.displayText)"
        default:
            return nil
        }
    }
}
