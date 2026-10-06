//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

@MainActor
final class FilmsAPI {
    private unowned let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func fetch(query: String, page: Int, size: Int) async throws -> PagedResult<ExploreItem> {
        let account = try appState.requireActiveAccount()

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/films",
            queryItems: [
                URLQueryItem(name: "query", value: query),
                URLQueryItem(name: "page", value: "\(max(page, 1))"),
                URLQueryItem(name: "size", value: "\(max(size, 1))")
            ]
        )
    }
}
