//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

@MainActor
final class TimelinesAPI {
    private unowned let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func fetchTimeline(kind: TimelineKind, maxId: String?) async throws -> LinkableResult<Status> {
        let account = try appState.requireActiveAccount()

        var queryItems = kind.queryItems
        if let maxId = maxId?.nilIfEmpty {
            queryItems.append(URLQueryItem(name: "maxId", value: maxId))
        }

        return try await appState.api.authorizedRequest(
            account: account,
            path: kind.path,
            queryItems: queryItems
        )
    }

    func fetchTrendingStatuses(period: TrendingPeriodSelection, maxId: String?) async throws -> LinkableResult<Status> {
        let account = try appState.requireActiveAccount()

        var queryItems = [
            URLQueryItem(name: "limit", value: "40"),
            URLQueryItem(name: "period", value: period.rawValue)
        ]

        if let maxId = maxId?.nilIfEmpty {
            queryItems.append(URLQueryItem(name: "maxId", value: maxId))
        }

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/trending/statuses",
            queryItems: queryItems
        )
    }

    func fetchFeaturedUsers(maxId: String?, limit: Int) async throws -> LinkableResult<User> {
        let account = try appState.requireActiveAccount()

        var queryItems = [URLQueryItem(name: "limit", value: "\(max(limit, 1))")]
        if let maxId = maxId?.nilIfEmpty {
            queryItems.append(URLQueryItem(name: "maxId", value: maxId))
        }

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/timelines/featured-users",
            queryItems: queryItems
        )
    }

    func fetchTrendingUsers(period: TrendingPeriodSelection, maxId: String?, limit: Int) async throws -> LinkableResult<User> {
        let account = try appState.requireActiveAccount()

        var queryItems = [
            URLQueryItem(name: "limit", value: "\(max(limit, 1))"),
            URLQueryItem(name: "period", value: period.rawValue)
        ]

        if let maxId = maxId?.nilIfEmpty {
            queryItems.append(URLQueryItem(name: "maxId", value: maxId))
        }

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/trending/users",
            queryItems: queryItems
        )
    }

    func fetchTrendingHashtags(period: TrendingPeriodSelection, maxId: String?, limit: Int) async throws -> LinkableResult<Hashtag> {
        let account = try appState.requireActiveAccount()

        var queryItems = [
            URLQueryItem(name: "limit", value: "\(max(limit, 1))"),
            URLQueryItem(name: "period", value: period.rawValue)
        ]

        if let maxId = maxId?.nilIfEmpty {
            queryItems.append(URLQueryItem(name: "maxId", value: maxId))
        }

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/trending/hashtags",
            queryItems: queryItems
        )
    }

    func fetchUserStatuses(userName: String, maxId: String?, limit: Int) async throws -> LinkableResult<Status> {
        let account = try appState.requireActiveAccount()

        let cleanedName = userName.trimmingPrefix("@")
        let encodedName = cleanedName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleanedName

        var queryItems = [URLQueryItem(name: "limit", value: "\(max(limit, 1))")]
        if let maxId = maxId?.nilIfEmpty {
            queryItems.append(URLQueryItem(name: "maxId", value: maxId))
        }

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/users/\(encodedName)/statuses",
            queryItems: queryItems
        )
    }

    func fetchHashtagStatuses(hashtag: String, maxId: String?, limit: Int) async throws -> LinkableResult<Status> {
        let account = try appState.requireActiveAccount()

        let cleanedName = hashtag.trimmingPrefix("#")
        let encodedName = cleanedName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleanedName

        var queryItems = [URLQueryItem(name: "limit", value: "\(max(limit, 1))")]
        if let maxId = maxId?.nilIfEmpty {
            queryItems.append(URLQueryItem(name: "maxId", value: maxId))
        }

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/timelines/hashtag/\(encodedName)",
            queryItems: queryItems
        )
    }

    func fetchCategoryStatuses(category: String, maxId: String?, limit: Int) async throws -> LinkableResult<Status> {
        let account = try appState.requireActiveAccount()

        let cleanedName = category
            .trimmingPrefix("#")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var queryItems = [URLQueryItem(name: "limit", value: "\(max(limit, 1))")]
        if let maxId = maxId?.nilIfEmpty {
            queryItems.append(URLQueryItem(name: "maxId", value: maxId))
        }

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/timelines/category/\(cleanedName)",
            queryItems: queryItems
        )
    }

    func fetchFavourites(maxId: String?, limit: Int) async throws -> LinkableResult<Status> {
        let account = try appState.requireActiveAccount()

        var queryItems = [URLQueryItem(name: "limit", value: "\(max(limit, 1))")]
        if let maxId = maxId?.nilIfEmpty {
            queryItems.append(URLQueryItem(name: "maxId", value: maxId))
        }

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/favourites",
            queryItems: queryItems
        )
    }

    func fetchBookmarks(maxId: String?, limit: Int) async throws -> LinkableResult<Status> {
        let account = try appState.requireActiveAccount()

        var queryItems = [URLQueryItem(name: "limit", value: "\(max(limit, 1))")]
        if let maxId = maxId?.nilIfEmpty {
            queryItems.append(URLQueryItem(name: "maxId", value: maxId))
        }

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/bookmarks",
            queryItems: queryItems
        )
    }

}
