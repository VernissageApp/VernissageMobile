//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

@MainActor
final class StatusesAPI {
    private unowned let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func updateStatusInteraction(statusId: String, action: StatusInteractionAction) async throws -> Status {
        let account = try appState.requireActiveAccount()

        var headers: [String: String] = [:]
        var body: Data?

        if action == .reblog {
            headers["Content-Type"] = "application/json"
            body = try JSONEncoder().encode(ReblogRequest(visibility: "public"))
        }

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/statuses/\(statusId)/\(action.pathSuffix)",
            method: "POST",
            queryItems: [],
            additionalHeaders: headers,
            body: body
        )
    }

    func fetchStatus(statusId: String) async throws -> Status {
        let account = try appState.requireActiveAccount()
        let encodedStatusId = statusId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? statusId

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/statuses/\(encodedStatusId)",
            queryItems: []
        )
    }

    func fetchStatusRebloggedBy(statusId: String, maxId: String?, limit: Int) async throws -> LinkableResult<User> {
        let account = try appState.requireActiveAccount()
        let encodedStatusId = statusId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? statusId

        var queryItems = [URLQueryItem(name: "limit", value: "\(max(limit, 1))")]
        if let maxId = maxId?.nilIfEmpty {
            queryItems.append(URLQueryItem(name: "maxId", value: maxId))
        }

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/statuses/\(encodedStatusId)/reblogged",
            queryItems: queryItems
        )
    }

    func fetchStatusFavouritedBy(statusId: String, maxId: String?, limit: Int) async throws -> LinkableResult<User> {
        let account = try appState.requireActiveAccount()
        let encodedStatusId = statusId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? statusId

        var queryItems = [URLQueryItem(name: "limit", value: "\(max(limit, 1))")]
        if let maxId = maxId?.nilIfEmpty {
            queryItems.append(URLQueryItem(name: "maxId", value: maxId))
        }

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/statuses/\(encodedStatusId)/favourited",
            queryItems: queryItems
        )
    }

    func deleteStatus(statusId: String) async throws {
        let account = try appState.requireActiveAccount()
        let encodedStatusId = statusId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? statusId

        try await appState.api.authorizedRequestNoContent(
            account: account,
            path: "/api/v1/statuses/\(encodedStatusId)",
            method: "DELETE",
            queryItems: []
        )
    }

    func applyContentWarning(statusId: String, contentWarning: String) async throws {
        let account = try appState.requireActiveAccount()
        let encodedStatusId = statusId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? statusId
        let payload = ContentWarningRequestBody(contentWarning: contentWarning)

        try await appState.api.authorizedRequestNoContent(
            account: account,
            path: "/api/v1/statuses/\(encodedStatusId)/apply-content-warning",
            method: "POST",
            queryItems: [],
            additionalHeaders: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(payload)
        )
    }

    func fetchStatusContext(statusId: String) async throws -> StatusContext {
        let account = try appState.requireActiveAccount()
        let encodedStatusId = statusId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? statusId

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/statuses/\(encodedStatusId)/context",
            queryItems: []
        )
    }

    func createComment(note: String, replyToStatusId: String) async throws -> Status {
        let account = try appState.requireActiveAccount()
        let request = NewStatusRequest(note: note, replyToStatusId: replyToStatusId)

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/statuses",
            method: "POST",
            queryItems: [],
            additionalHeaders: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(request)
        )
    }

    func createStatus(request: StatusComposeRequest) async throws -> Status {
        let account = try appState.requireActiveAccount()

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/statuses",
            method: "POST",
            queryItems: [],
            additionalHeaders: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(request)
        )
    }

    func updateStatus(statusId: String, request: StatusComposeRequest) async throws -> Status {
        let account = try appState.requireActiveAccount()
        let encodedStatusId = statusId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? statusId

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/statuses/\(encodedStatusId)",
            method: "PUT",
            queryItems: [],
            additionalHeaders: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(request)
        )
    }

}
