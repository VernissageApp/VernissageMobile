//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

@MainActor
final class UsersAPI {
    private unowned let appState: AppState
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    init(appState: AppState) {
        self.appState = appState
    }

    func fetchProfile(for account: StoredAccount) async throws -> User {
        let encodedName = encodeUserName(account.userName)

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/users/\(encodedName)",
            queryItems: []
        )
    }

    func fetchUserProfile(userName: String) async throws -> User {
        let account = try appState.requireActiveAccount()
        let encodedName = encodeUserName(userName)

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/users/\(encodedName)",
            queryItems: []
        )
    }

    func fetchRelationships(userIds: [String]) async throws -> [Relationship] {
        let account = try appState.requireActiveAccount()
        let cleanedIds = Array(Set(userIds.compactMap { $0.nilIfEmpty }))
        guard !cleanedIds.isEmpty else {
            return []
        }

        let queryItems = cleanedIds.map { URLQueryItem(name: "id[]", value: $0) }

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/relationships",
            queryItems: queryItems
        )
    }

    func fetchRelationship(userId: String) async throws -> Relationship {
        let relationships = try await fetchRelationships(userIds: [userId])
        return relationships.first ?? Relationship(userId: userId)
    }
    
    func follow(userName: String) async throws -> Relationship {
        let account = try appState.requireActiveAccount()
        let encodedName = encodeUserName(userName)

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/users/@\(encodedName)/follow",
            method: "POST",
            queryItems: []
        )
    }

    func unfollow(userName: String) async throws -> Relationship {
        let account = try appState.requireActiveAccount()
        let encodedName = encodeUserName(userName)

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/users/@\(encodedName)/unfollow",
            method: "POST",
            queryItems: []
        )
    }

    func mute(
        userName: String,
        muteStatuses: Bool,
        muteReblogs: Bool,
        muteNotifications: Bool,
        muteEnd: Date?
    ) async throws -> Relationship {
        let account = try appState.requireActiveAccount()
        let encodedName = encodeUserName(userName)

        let payload = UserMuteRequestBody(
            muteStatuses: muteStatuses,
            muteReblogs: muteReblogs,
            muteNotifications: muteNotifications,
            muteEnd: muteEnd.map { Self.iso8601Formatter.string(from: $0) }
        )

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/users/@\(encodedName)/mute",
            method: "POST",
            queryItems: [],
            additionalHeaders: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(payload)
        )
    }

    func unmute(userName: String) async throws -> Relationship {
        let account = try appState.requireActiveAccount()
        let encodedName = encodeUserName(userName)

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/users/@\(encodedName)/unmute",
            method: "POST",
            queryItems: []
        )
    }

    func featureUser(userName: String) async throws -> User {
        let account = try appState.requireActiveAccount()
        let encodedName = encodeUserName(userName)

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/users/@\(encodedName)/feature",
            method: "POST",
            queryItems: []
        )
    }

    func unfeatureUser(userName: String) async throws -> User {
        let account = try appState.requireActiveAccount()
        let encodedName = encodeUserName(userName)

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/users/@\(encodedName)/unfeature",
            method: "POST",
            queryItems: []
        )
    }

    func blockDomain(domain: String, reason: String?) async throws {
        let account = try appState.requireActiveAccount()
        let payload = UserBlockedDomainRequest(
            domain: domain,
            reason: reason?.nilIfEmpty
        )

        try await appState.api.authorizedRequestNoContent(
            account: account,
            path: "/api/v1/user-blocked-domains",
            method: "POST",
            queryItems: [],
            additionalHeaders: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(payload)
        )
    }

    func approveFollowRequest(userId: String) async throws -> Relationship {
        let account = try appState.requireActiveAccount()
        let encodedId = userId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? userId

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/follow-requests/\(encodedId)/approve",
            method: "POST",
            queryItems: []
        )
    }

    func rejectFollowRequest(userId: String) async throws -> Relationship {
        let account = try appState.requireActiveAccount()
        let encodedId = userId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? userId

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/follow-requests/\(encodedId)/reject",
            method: "POST",
            queryItems: []
        )
    }

    func fetchUserFollowing(userName: String, maxId: String?, limit: Int) async throws -> LinkableResult<User> {
        let account = try appState.requireActiveAccount()
        let encodedName = encodeUserName(userName)

        var queryItems = [URLQueryItem(name: "limit", value: "\(max(limit, 1))")]
        if let maxId = maxId?.nilIfEmpty {
            queryItems.append(URLQueryItem(name: "maxId", value: maxId))
        }

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/users/\(encodedName)/following",
            queryItems: queryItems
        )
    }

    func fetchUserFollowers(userName: String, maxId: String?, limit: Int) async throws -> LinkableResult<User> {
        let account = try appState.requireActiveAccount()
        let encodedName = encodeUserName(userName)

        var queryItems = [URLQueryItem(name: "limit", value: "\(max(limit, 1))")]
        if let maxId = maxId?.nilIfEmpty {
            queryItems.append(URLQueryItem(name: "maxId", value: maxId))
        }

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/users/\(encodedName)/followers",
            queryItems: queryItems
        )
    }
    
    func fetchLatestFollowers(userName: String, limit: Int = 10) async throws -> [User] {
        let result = try await fetchUserFollowers(userName: userName, maxId: nil, limit: limit)
        return result.data
    }

    func updateActiveProfile(request: UpdateProfileRequest) async throws -> User {
        let account = try appState.requireActiveAccount()
        let encodedName = encodeUserName(account.userName)

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/users/@\(encodedName)",
            method: "PUT",
            queryItems: [],
            additionalHeaders: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(request)
        )
    }

    func uploadActiveAvatar(imageData: Data, fileName: String, mimeType: String) async throws {
        let account = try appState.requireActiveAccount()
        let encodedName = encodeUserName(account.userName)

        let boundary = "Boundary-\(UUID().uuidString)"
        let requestBody = MultipartFormDataBuilder.buildSingleFileBody(
            boundary: boundary,
            fieldName: "file",
            fileName: fileName,
            mimeType: mimeType,
            fileData: imageData
        )

        try await appState.api.authorizedRequestNoContent(
            account: account,
            path: "/api/v1/avatars/@\(encodedName)",
            method: "POST",
            queryItems: [],
            additionalHeaders: ["Content-Type": "multipart/form-data; boundary=\(boundary)"],
            body: requestBody
        )
    }

    func deleteActiveAvatar() async throws {
        let account = try appState.requireActiveAccount()
        let encodedName = encodeUserName(account.userName)

        try await appState.api.authorizedRequestNoContent(
            account: account,
            path: "/api/v1/avatars/@\(encodedName)",
            method: "DELETE",
            queryItems: []
        )
    }

    func uploadActiveHeader(imageData: Data, fileName: String, mimeType: String) async throws {
        let account = try appState.requireActiveAccount()
        let encodedName = encodeUserName(account.userName)

        let boundary = "Boundary-\(UUID().uuidString)"
        let requestBody = MultipartFormDataBuilder.buildSingleFileBody(
            boundary: boundary,
            fieldName: "file",
            fileName: fileName,
            mimeType: mimeType,
            fileData: imageData
        )

        try await appState.api.authorizedRequestNoContent(
            account: account,
            path: "/api/v1/headers/@\(encodedName)",
            method: "POST",
            queryItems: [],
            additionalHeaders: ["Content-Type": "multipart/form-data; boundary=\(boundary)"],
            body: requestBody
        )
    }

    func deleteActiveHeader() async throws {
        let account = try appState.requireActiveAccount()
        let encodedName = encodeUserName(account.userName)

        try await appState.api.authorizedRequestNoContent(
            account: account,
            path: "/api/v1/headers/@\(encodedName)",
            method: "DELETE",
            queryItems: []
        )
    }

    func deleteActiveAccount() async throws {
        let account = try appState.requireActiveAccount()
        let encodedName = encodeUserName(account.userName)

        try await appState.api.authorizedRequestNoContent(
            account: account,
            path: "/api/v1/users/@\(encodedName)",
            method: "DELETE",
            queryItems: []
        )
    }

    private func encodeUserName(_ userName: String) -> String {
        let cleanedName = userName.trimmingPrefix("@")
        return cleanedName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleanedName
    }
}
