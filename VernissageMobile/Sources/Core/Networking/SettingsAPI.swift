//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

@MainActor
final class SettingsAPI {
    private struct BooleanResponse: Decodable {
        let result: Bool
    }

    private struct ResendEmailConfirmationRequest: Encodable {
        let redirectBaseUrl: String
    }

    private unowned let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func fetchPublicSettings() async throws -> PublicSettings {
        let account = try appState.requireActiveAccount()

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/settings/public",
            queryItems: [],
            showToastOnError: false
        )
    }

    func fetchEmailVerified() async throws -> Bool {
        let account = try appState.requireActiveAccount()
        let response: BooleanResponse = try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/account/email/verified",
            queryItems: [],
            showToastOnError: false
        )

        return response.result
    }

    func resendEmailConfirmation() async throws {
        let account = try appState.requireActiveAccount()
        let redirectBaseUrl = try URLSanitizer.sanitizeBaseURL(account.instanceURL).absoluteString
        let payload = ResendEmailConfirmationRequest(redirectBaseUrl: redirectBaseUrl)

        try await appState.api.authorizedRequestNoContent(
            account: account,
            path: "/api/v1/account/email/resend",
            method: "POST",
            queryItems: [],
            additionalHeaders: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(payload),
            showToastOnError: false
        )
    }

    func fetchUserSetting(key: String) async throws -> UserSetting? {
        let account = try appState.requireActiveAccount()
        let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? key

        do {
            let setting: UserSetting = try await appState.api.authorizedRequest(
                account: account,
                path: "/api/v1/user-settings/\(encodedKey)",
                queryItems: [],
                showToastOnError: false
            )
            return setting
        } catch let APIError.http(statusCode, _) where statusCode == 404 {
            return nil
        }
    }

    func setUserSetting(key: String, value: String) async throws -> UserSetting {
        let account = try appState.requireActiveAccount()
        let payload = UserSetting(key: key, value: value)

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/user-settings",
            method: "PUT",
            queryItems: [],
            additionalHeaders: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(payload)
        )
    }

    func fetchCategories() async throws -> [Category] {
        let account = try appState.requireActiveAccount()

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/categories/all",
            queryItems: [URLQueryItem(name: "onlyUsed", value: "false")]
        )
    }

    func fetchLicenses() async throws -> [License] {
        let account = try appState.requireActiveAccount()

        let result: PagedResult<License> = try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/licenses",
            queryItems: [
                URLQueryItem(name: "page", value: "1"),
                URLQueryItem(name: "size", value: "100")
            ]
        )

        return result.data ?? []
    }

    func fetchCountries() async throws -> [Country] {
        let account = try appState.requireActiveAccount()

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/countries",
            queryItems: []
        )
    }

    func searchLocations(countryCode: String, query: String) async throws -> [Location] {
        let account = try appState.requireActiveAccount()
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return []
        }

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/locations",
            queryItems: [
                URLQueryItem(name: "code", value: countryCode),
                URLQueryItem(name: "query", value: trimmedQuery)
            ]
        )
    }

}
