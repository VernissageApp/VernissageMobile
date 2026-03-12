//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

@MainActor
final class APIServiceContainer {
    private unowned let appState: AppState

    let timelines: TimelinesAPI
    let notifications: NotificationsAPI
    let search: SearchAPI
    let statuses: StatusesAPI
    let attachments: AttachmentsAPI
    let settings: SettingsAPI
    let users: UsersAPI
    let businessCards: BusinessCardsAPI
    let instance: InstanceAPI
    let reports: ReportsAPI

    init(appState: AppState) {
        self.appState = appState
        timelines = TimelinesAPI(appState: appState)
        notifications = NotificationsAPI(appState: appState)
        search = SearchAPI(appState: appState)
        statuses = StatusesAPI(appState: appState)
        attachments = AttachmentsAPI(appState: appState)
        settings = SettingsAPI(appState: appState)
        users = UsersAPI(appState: appState)
        businessCards = BusinessCardsAPI(appState: appState)
        instance = InstanceAPI(appState: appState)
        reports = ReportsAPI(appState: appState)
    }

    func authorizedRequest<T: Decodable>(
        account: StoredAccount,
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem],
        additionalHeaders: [String: String] = [:],
        body: Data? = nil,
        showToastOnError: Bool = true
    ) async throws -> T {
        var headers = ["Authorization": "Bearer \(account.accessToken)"]
        additionalHeaders.forEach { headers[$0.key] = $0.value }

        do {
            return try await APIClient.requestJSON(
                baseURL: URLSanitizer.sanitizeBaseURL(account.instanceURL),
                path: path,
                method: method,
                queryItems: queryItems,
                headers: headers,
                body: body
            )
        } catch let APIError.http(statusCode, _) where statusCode == 401 {
            guard let refreshed = try await appState.refreshAccessToken(for: account) else {
                throw APIError.http(statusCode: 401, body: "Access token expired and no refresh token available.")
            }

            var refreshedHeaders = ["Authorization": "Bearer \(refreshed.accessToken)"]
            additionalHeaders.forEach { refreshedHeaders[$0.key] = $0.value }

            do {
                return try await APIClient.requestJSON(
                    baseURL: URLSanitizer.sanitizeBaseURL(refreshed.instanceURL),
                    path: path,
                    method: method,
                    queryItems: queryItems,
                    headers: refreshedHeaders,
                    body: body
                )
            } catch {
                if showToastOnError {
                    appState.showErrorToast((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
                }
                throw error
            }
        } catch {
            if showToastOnError {
                appState.showErrorToast((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            }
            throw error
        }
    }

    func authorizedRequestNoContent(
        account: StoredAccount,
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem],
        additionalHeaders: [String: String] = [:],
        body: Data? = nil,
        showToastOnError: Bool = true
    ) async throws {
        var headers = ["Authorization": "Bearer \(account.accessToken)"]
        additionalHeaders.forEach { headers[$0.key] = $0.value }

        do {
            try await APIClient.requestNoContent(
                baseURL: URLSanitizer.sanitizeBaseURL(account.instanceURL),
                path: path,
                method: method,
                queryItems: queryItems,
                headers: headers,
                body: body
            )
        } catch let APIError.http(statusCode, _) where statusCode == 401 {
            guard let refreshed = try await appState.refreshAccessToken(for: account) else {
                throw APIError.http(statusCode: 401, body: "Access token expired and no refresh token available.")
            }

            var refreshedHeaders = ["Authorization": "Bearer \(refreshed.accessToken)"]
            additionalHeaders.forEach { refreshedHeaders[$0.key] = $0.value }

            do {
                try await APIClient.requestNoContent(
                    baseURL: URLSanitizer.sanitizeBaseURL(refreshed.instanceURL),
                    path: path,
                    method: method,
                    queryItems: queryItems,
                    headers: refreshedHeaders,
                    body: body
                )
            } catch {
                if showToastOnError {
                    appState.showErrorToast((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
                }
                throw error
            }
        } catch {
            if showToastOnError {
                appState.showErrorToast((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            }
            throw error
        }
    }
}
