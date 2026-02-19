//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidInstanceURL
    case invalidRedirectURI
    case oauthCallbackMissing
    case oauthCallbackMissingCode
    case invalidTokenPayload
    case noActiveAccount
    case http(statusCode: Int, body: String)
    case decoding(String)
    case keychainWrite(OSStatus)
    case keychainRead(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Cannot construct request URL."
        case .invalidResponse:
            return "Server returned invalid response."
        case .invalidInstanceURL:
            return "Instance URL is not valid."
        case .invalidRedirectURI:
            return "OAuth redirect URI is not valid."
        case .oauthCallbackMissing:
            return "OAuth callback was not returned."
        case .oauthCallbackMissingCode:
            return "OAuth callback does not contain authorization code."
        case .invalidTokenPayload:
            return "Cannot read user data from access token."
        case .noActiveAccount:
            return "No active account. Add account first."
        case .http(let statusCode, let body):
            return "HTTP \(statusCode): \(body.nilIfEmpty ?? "No details.")"
        case .decoding(let message):
            return "Response decoding error: \(message)"
        case .keychainWrite(let status):
            return "Cannot write to Keychain (\(status))."
        case .keychainRead(let status):
            return "Cannot read from Keychain (\(status))."
        }
    }
}
