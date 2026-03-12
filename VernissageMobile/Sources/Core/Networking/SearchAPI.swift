//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

@MainActor
final class SearchAPI {
    private unowned let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func search(query: String, type: String) async throws -> SearchResult {
        let account = try appState.requireActiveAccount()
        let queryWithoutHashtags = query.replacingOccurrences(of: "#", with: "")
        let queryItems = [
            URLQueryItem(name: "query", value: queryWithoutHashtags),
            URLQueryItem(name: "type", value: type)
        ]

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/search",
            queryItems: queryItems
        )
    }

}
