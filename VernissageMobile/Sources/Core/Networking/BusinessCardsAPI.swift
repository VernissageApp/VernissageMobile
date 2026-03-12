//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

@MainActor
final class BusinessCardsAPI {
    private unowned let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func activeBusinessCardExists() async throws -> Bool {
        let account = try appState.requireActiveAccount()

        do {
            let _: BusinessCard = try await appState.api.authorizedRequest(
                account: account,
                path: "/api/v1/business-cards",
                queryItems: [],
                showToastOnError: false
            )
            return true
        } catch let APIError.http(statusCode, _) where statusCode == 404 {
            return false
        }
    }

    func fetchSharedBusinessCards(page: Int, size: Int) async throws -> PagedResult<SharedBusinessCard> {
        let account = try appState.requireActiveAccount()

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/shared-business-cards",
            queryItems: [
                URLQueryItem(name: "page", value: "\(max(page, 1))"),
                URLQueryItem(name: "size", value: "\(max(size, 1))")
            ]
        )
    }

    func fetchSharedBusinessCard(id: String) async throws -> SharedBusinessCard {
        let account = try appState.requireActiveAccount()
        let encodedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/shared-business-cards/\(encodedId)",
            queryItems: []
        )
    }

    func sendSharedBusinessCardMessage(id: String, message: String) async throws {
        let account = try appState.requireActiveAccount()
        let encodedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id

        let payload = SharedBusinessCardMessageRequest(
            message: message,
            addedByUser: true
        )

        try await appState.api.authorizedRequestNoContent(
            account: account,
            path: "/api/v1/shared-business-cards/\(encodedId)/message",
            method: "POST",
            queryItems: [],
            additionalHeaders: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(payload)
        )
    }

    func createSharedBusinessCard(
        title: String,
        note: String?,
        thirdPartyName: String?,
        thirdPartyEmail: String?
    ) async throws -> SharedBusinessCard {
        let account = try appState.requireActiveAccount()

        let payload = SharedBusinessCardRequest(
            title: title,
            note: note?.nilIfEmpty,
            thirdPartyName: thirdPartyName?.nilIfEmpty,
            thirdPartyEmail: thirdPartyEmail?.nilIfEmpty
        )

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/shared-business-cards",
            method: "POST",
            queryItems: [],
            additionalHeaders: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(payload)
        )
    }

    func updateSharedBusinessCard(
        id: String,
        title: String,
        note: String?,
        thirdPartyName: String?,
        thirdPartyEmail: String?
    ) async throws -> SharedBusinessCard {
        let account = try appState.requireActiveAccount()
        let encodedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id

        let payload = SharedBusinessCardRequest(
            title: title,
            note: note?.nilIfEmpty,
            thirdPartyName: thirdPartyName?.nilIfEmpty,
            thirdPartyEmail: thirdPartyEmail?.nilIfEmpty
        )

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/shared-business-cards/\(encodedId)",
            method: "PUT",
            queryItems: [],
            additionalHeaders: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(payload)
        )
    }

    func deleteSharedBusinessCard(id: String) async throws {
        let account = try appState.requireActiveAccount()
        let encodedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id

        try await appState.api.authorizedRequestNoContent(
            account: account,
            path: "/api/v1/shared-business-cards/\(encodedId)",
            method: "DELETE",
            queryItems: []
        )
    }

    func revokeSharedBusinessCard(id: String) async throws {
        let account = try appState.requireActiveAccount()
        let encodedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id

        try await appState.api.authorizedRequestNoContent(
            account: account,
            path: "/api/v1/shared-business-cards/\(encodedId)/revoke",
            method: "POST",
            queryItems: []
        )
    }

    func unrevokeSharedBusinessCard(id: String) async throws {
        let account = try appState.requireActiveAccount()
        let encodedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id

        try await appState.api.authorizedRequestNoContent(
            account: account,
            path: "/api/v1/shared-business-cards/\(encodedId)/unrevoke",
            method: "POST",
            queryItems: []
        )
    }
}
