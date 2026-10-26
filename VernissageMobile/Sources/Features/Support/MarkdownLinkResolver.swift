//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

@MainActor
enum MarkdownLinkResolver {
    static func profileRoute(userName: String, using appState: AppState) async throws -> MentionedUserRoute? {
        let result = try await appState.api.search.search(query: userName, type: SearchScopeSelection.users.rawValue)

        guard let matchedUser = preferredMentionSearchUser(in: result.users ?? [], query: userName),
              let userName = routeUserName(from: matchedUser) else {
            return nil
        }

        return MentionedUserRoute(userName: userName, preferredDisplayName: matchedUser.name?.nilIfEmpty)
    }

    static func hashtagName(from url: URL) -> String? {
        if let fragment = url.fragment?.nilIfEmpty {
            let normalizedFragment = fragment.trimmingPrefix("#")

            if !normalizedFragment.isEmpty {
                return normalizedFragment
            }
        }

        let pathComponents = url.pathComponents

        if pathComponents.contains(where: { $0.caseInsensitiveCompare("tags") == .orderedSame }),
           let lastComponent = pathComponents.last?.nilIfEmpty {
            let normalizedTag = lastComponent.trimmingPrefix("#")

            return normalizedTag.nilIfEmpty
        }

        return nil
    }

    static func userName(from url: URL) -> String? {
        userNameFromAtPath(url)
    }

    private static func userNameFromAtPath(_ url: URL) -> String? {
        guard let lastPathComponent = url.lastPathComponent.nilIfEmpty,
              lastPathComponent.first == "@",
              let host = url.host?.nilIfEmpty else {
            return nil
        }

        let userPart = lastPathComponent
            .trimmingPrefix("@")
            .split(separator: "@", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map(String.init)

        guard let normalizedUserPart = userPart?.nilIfEmpty else {
            return nil
        }

        return "\(normalizedUserPart)@\(host)"
    }

    private static func preferredMentionSearchUser(in users: [User], query: String) -> User? {
        let normalizedQuery = query.trimmingPrefix("@").lowercased()

        guard !users.isEmpty else {
            return nil
        }

        // Match federated account names before using the server's preferred search result.
        if let exactMatch = users.first(where: { user in
            let userName = user.userName?.trimmingPrefix("@").lowercased()
            let account = user.account?.trimmingPrefix("@").lowercased()

            return userName == normalizedQuery || account == normalizedQuery
        }) {
            return exactMatch
        }

        return users.first
    }

    private static func routeUserName(from user: User) -> String? {
        if let userName = user.userName?.trimmingPrefix("@").nilIfEmpty {
            return userName
        }

        if let account = user.account?.trimmingPrefix("@").nilIfEmpty {
            return account
        }

        return nil
    }
}
