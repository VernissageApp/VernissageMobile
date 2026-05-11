//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

@MainActor
final class HashtagsAPI {
    private unowned let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func fetchFollowedHashtags() async throws -> [Hashtag] {
        let account = try appState.requireActiveAccount()

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/hashtags/followed",
            queryItems: []
        )
    }

    func follow(hashtagName: String) async throws {
        let account = try appState.requireActiveAccount()
        let encodedName = encodeHashtagName(hashtagName)

        try await appState.api.authorizedRequestNoContent(
            account: account,
            path: "/api/v1/hashtags/\(encodedName)/follow",
            method: "POST",
            queryItems: []
        )
    }

    func unfollow(hashtagName: String) async throws {
        let account = try appState.requireActiveAccount()
        let encodedName = encodeHashtagName(hashtagName)

        try await appState.api.authorizedRequestNoContent(
            account: account,
            path: "/api/v1/hashtags/\(encodedName)/unfollow",
            method: "POST",
            queryItems: []
        )
    }

    private func encodeHashtagName(_ hashtagName: String) -> String {
        let cleanedName = hashtagName
            .trimmingPrefix("#")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanedName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleanedName
    }
}
