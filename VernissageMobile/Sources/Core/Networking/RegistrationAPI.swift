//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

enum RegistrationAPI {
    struct ServerError: LocalizedError {
        struct Failure: Decodable {
            let field: String?
            let failure: String?
        }

        private struct ErrorBody: Decodable {
            let code: String?
            let reason: String?
            let failures: [Failure]?
        }

        let statusCode: Int
        let code: String?
        let reason: String?
        let failures: [Failure]
        let rawBody: String

        init(statusCode: Int, body: String) {
            self.statusCode = statusCode
            self.rawBody = body

            guard let data = body.data(using: .utf8),
                  let errorBody = try? APIClient.jsonDecoder.decode(ErrorBody.self, from: data) else {
                self.code = nil
                self.reason = nil
                self.failures = []
                return
            }

            self.code = errorBody.code?.nilIfEmpty
            self.reason = errorBody.reason?.nilIfEmpty
            self.failures = errorBody.failures ?? []
        }

        var errorDescription: String? {
            reason ?? rawBody.nilIfEmpty ?? "Registration failed."
        }
    }

    static func fetchInstanceDetails(at baseURL: URL) async throws -> InstanceDetails {
        try await APIClient.requestJSON(
            baseURL: baseURL,
            path: "/api/v1/instance",
            method: "GET",
            cachePolicy: .reloadIgnoringLocalCacheData
        )
    }

    static func fetchPublicSettings(at baseURL: URL) async throws -> PublicSettings {
        try await APIClient.requestJSON(
            baseURL: baseURL,
            path: "/api/v1/settings/public",
            method: "GET",
            cachePolicy: .reloadIgnoringLocalCacheData
        )
    }

    static func isUserNameTaken(_ userName: String, at baseURL: URL) async throws -> Bool {
        let encodedUserName = userName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? userName
        let result: BooleanResult = try await APIClient.requestJSON(
            baseURL: baseURL,
            path: "/api/v1/register/username/\(encodedUserName)",
            method: "GET",
            cachePolicy: .reloadIgnoringLocalCacheData
        )

        return result.result
    }

    static func isEmailConnected(_ email: String, at baseURL: URL) async throws -> Bool {
        let encodedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? email
        let result: BooleanResult = try await APIClient.requestJSON(
            baseURL: baseURL,
            path: "/api/v1/register/email/\(encodedEmail)",
            method: "GET",
            cachePolicy: .reloadIgnoringLocalCacheData
        )

        return result.result
    }

    static func register(_ request: RegisterUserRequest, at baseURL: URL) async throws -> User {
        do {
            return try await APIClient.requestJSON(
                baseURL: baseURL,
                path: "/api/v1/register",
                method: "POST",
                headers: ["Content-Type": "application/json"],
                body: try JSONEncoder().encode(request),
                cachePolicy: .reloadIgnoringLocalCacheData
            )
        } catch let APIError.http(statusCode, body) {
            throw ServerError(statusCode: statusCode, body: body)
        }
    }

    static func captchaImageURL(baseURL: URL, key: String) -> URL? {
        var components = URLComponents(url: baseURL.appending(path: "/api/v1/quick-captcha/generate"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "key", value: key)]
        return components?.url
    }
}
