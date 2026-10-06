//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

@MainActor
final class CategoriesAPI {
    private unowned let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func fetchAll(onlyUsed: Bool) async throws -> [ExploreItem] {
        let account = try appState.requireActiveAccount()

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/categories/all",
            queryItems: [URLQueryItem(name: "onlyUsed", value: onlyUsed ? "true" : "false")]
        )
    }
}
