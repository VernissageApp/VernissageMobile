//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI
import AuthenticationServices

@MainActor
final class OAuthCoordinator: NSObject {
    private var activeSession: ASWebAuthenticationSession?
    private let contextProvider = OAuthPresentationContextProvider()

    func authorize(baseURL: URL,
                   clientID: String,
                   redirectURI: String,
                   scope: String) async throws -> String {
        let callbackScheme = URL(string: redirectURI)?.scheme
        guard let callbackScheme else {
            throw APIError.invalidRedirectURI
        }

        let state = UUID().uuidString
        let nonce = UUID().uuidString.replacingOccurrences(of: "-", with: "")

        var components = URLComponents(url: baseURL.appending(path: "/api/v1/oauth/authorize"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "nonce", value: nonce)
        ]

        guard let authorizationURL = components?.url else {
            throw APIError.invalidURL
        }

        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(url: authorizationURL,
                                                     callbackURLScheme: callbackScheme) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL else {
                    continuation.resume(throwing: APIError.oauthCallbackMissing)
                    return
                }

                continuation.resume(returning: callbackURL)
            }

            session.presentationContextProvider = contextProvider
            // Force a fresh login flow every time to avoid reusing stale browser session state.
            session.prefersEphemeralWebBrowserSession = true

            self.activeSession = session
            session.start()
        }

        activeSession = nil

        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              !code.isEmpty else {
            throw APIError.oauthCallbackMissingCode
        }

        return code
    }
}

