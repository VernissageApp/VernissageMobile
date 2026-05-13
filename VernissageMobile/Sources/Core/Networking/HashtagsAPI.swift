//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

@MainActor
final class HashtagsAPI {
    private unowned let appState: AppState
    private var followedHashtagsCacheByAccountID: [UUID: [Hashtag]] = [:]

    init(appState: AppState) {
        self.appState = appState
    }

    func fetchFollowedHashtags(forceRefresh: Bool = false) async throws -> [Hashtag] {
        let account = try appState.requireActiveAccount()
        if !forceRefresh, let cachedHashtags = followedHashtagsCacheByAccountID[account.id] {
            return cachedHashtags
        }

        let followedHashtags: [Hashtag] = try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/hashtags/followed",
            queryItems: []
        )

        followedHashtagsCacheByAccountID[account.id] = followedHashtags
        return followedHashtags
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

        invalidateFollowedHashtagsCache(for: account.id)
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

        invalidateFollowedHashtagsCache(for: account.id)
    }

    private func encodeHashtagName(_ hashtagName: String) -> String {
        let cleanedName = hashtagName
            .trimmingPrefix("#")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCompatibilityMapping
        return cleanedName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleanedName
    }

    private func invalidateFollowedHashtagsCache(for accountID: UUID) {
        followedHashtagsCacheByAccountID[accountID] = nil
    }
}
