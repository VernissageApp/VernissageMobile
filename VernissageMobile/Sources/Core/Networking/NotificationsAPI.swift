//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

@MainActor
final class NotificationsAPI {
    private unowned let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func fetchNotifications(maxId: String?) async throws -> LinkableResult<AppNotification> {
        let account = try appState.requireActiveAccount()

        var queryItems = [URLQueryItem(name: "limit", value: "40")]
        if let maxId = maxId?.nilIfEmpty {
            queryItems.append(URLQueryItem(name: "maxId", value: maxId))
        }

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/notifications",
            queryItems: queryItems
        )
    }

    func fetchNotificationsCount() async throws -> NotificationsCount {
        let account = try appState.requireActiveAccount()

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/notifications/count",
            queryItems: []
        )
    }

    func updateNotificationMarker(notificationId: String) async throws {
        let account = try appState.requireActiveAccount()
        let encodedNotificationId = notificationId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? notificationId

        try await appState.api.authorizedRequestNoContent(
            account: account,
            path: "/api/v1/notifications/marker/\(encodedNotificationId)",
            method: "POST",
            queryItems: []
        )
    }

}
