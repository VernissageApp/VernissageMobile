//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

@MainActor
final class PushSubscriptionsAPI {
    private unowned let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func fetchPushSubscriptions(page: Int = 1, size: Int = 100) async throws -> PagedResult<PushSubscription> {
        let account = try appState.requireActiveAccount()

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/push-subscriptions",
            queryItems: [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(size))
            ],
            showToastOnError: false
        )
    }

    func createPushSubscription(_ pushSubscription: PushSubscription) async throws -> PushSubscription {
        let account = try appState.requireActiveAccount()

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/push-subscriptions",
            method: "POST",
            queryItems: [],
            additionalHeaders: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(pushSubscription)
        )
    }

    func updatePushSubscription(id: String, pushSubscription: PushSubscription) async throws -> PushSubscription {
        let account = try appState.requireActiveAccount()
        let encodedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/push-subscriptions/\(encodedId)",
            method: "PUT",
            queryItems: [],
            additionalHeaders: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(pushSubscription)
        )
    }
}
