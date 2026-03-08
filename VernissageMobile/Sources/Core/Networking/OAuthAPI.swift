//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

enum OAuthAPI {
    static func registerClient(at baseURL: URL, redirectURI: String, scope: String) async throws -> OAuthDynamicClientRegistrationResponse {
        let request = OAuthDynamicClientRegistrationRequest(
            redirectUris: [redirectURI],
            tokenEndpointAuthMethod: "none",
            grantTypes: ["authorization_code", "refresh_token"],
            responseTypes: ["code"],
            clientName: AppConstants.OAuth.clientName,
            scope: scope,
            softwareId: "vernissage-ios-native",
            softwareVersion: Bundle.main.appVersionLabel
        )

        return try await APIClient.requestJSON(
            baseURL: baseURL,
            path: "/api/v1/auth-dynamic-clients",
            method: "POST",
            headers: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(request)
        )
    }

    static func exchangeCode(at baseURL: URL,
                             code: String,
                             clientID: String,
                             clientSecret: String?,
                             redirectURI: String) async throws -> OAuthTokenResponse {
        var body = [
            "grant_type": "authorization_code",
            "code": code,
            "client_id": clientID,
            "redirect_uri": redirectURI
        ]

        if let clientSecret, !clientSecret.isEmpty {
            body["client_secret"] = clientSecret
        }

        return try await requestToken(at: baseURL, body: body)
    }

    static func refreshToken(at baseURL: URL,
                             refreshToken: String,
                             clientID: String,
                             clientSecret: String?) async throws -> OAuthTokenResponse {
        var body = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientID
        ]

        if let clientSecret, !clientSecret.isEmpty {
            body["client_secret"] = clientSecret
        }

        return try await requestToken(at: baseURL, body: body)
    }

    private static func requestToken(at baseURL: URL,
                                     body: [String: String]) async throws -> OAuthTokenResponse {
        let bodyData = body
            .map { key, value in
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? value
                return "\(key)=\(encodedValue)"
            }
            .sorted()
            .joined(separator: "&")
            .data(using: .utf8)

        return try await APIClient.requestJSON(
            baseURL: baseURL,
            path: "/api/v1/oauth/token",
            method: "POST",
            headers: ["Content-Type": "application/x-www-form-urlencoded"],
            body: bodyData
        )
    }

}
