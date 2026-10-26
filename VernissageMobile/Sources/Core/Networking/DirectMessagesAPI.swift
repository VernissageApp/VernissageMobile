//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

@MainActor
final class DirectMessagesAPI {
    private unowned let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func conversations(page: Int) async throws -> DirectMessagesPage<DirectConversation> {
        try await appState.api.authorizedRequest(
            account: appState.requireActiveAccount(),
            path: AppConstants.DirectMessages.apiPath,
            queryItems: pageQuery(page),
            showToastOnError: false
        )
    }

    func conversation(id: String) async throws -> DirectConversation {
        try await appState.api.authorizedRequest(
            account: appState.requireActiveAccount(),
            path: path(id),
            queryItems: [],
            showToastOnError: false
        )
    }

    func messages(id: String, page: Int) async throws -> DirectMessagesPage<DirectMessage> {
        try await appState.api.authorizedRequest(
            account: appState.requireActiveAccount(),
            path: path(id) + "/statuses",
            queryItems: pageQuery(page),
            showToastOnError: false
        )
    }

    func send(_ request: DirectMessageRequest, conversationID: String?) async throws -> DirectMessage {
        try await appState.api.authorizedRequest(
            account: appState.requireActiveAccount(),
            path: conversationID.map { path($0) + "/statuses" } ?? AppConstants.DirectMessages.apiPath,
            method: "POST",
            queryItems: [],
            additionalHeaders: ["Content-Type": "application/json"],
            body: JSONEncoder().encode(request),
            showToastOnError: false
        )
    }

    func markRead(id: String, statusIDs: [String]) async throws {
        try await appState.api.authorizedRequestNoContent(
            account: appState.requireActiveAccount(),
            path: path(id) + "/read",
            method: "POST",
            queryItems: [],
            additionalHeaders: ["Content-Type": "application/json"],
            body: JSONEncoder().encode(DirectMessageReadRequest(statusIds: statusIDs)),
            showToastOnError: false
        )
    }

    func mute(id: String, isMuted: Bool) async throws {
        try await appState.api.authorizedRequestNoContent(
            account: appState.requireActiveAccount(),
            path: path(id) + "/mute",
            method: "PUT",
            queryItems: [],
            additionalHeaders: ["Content-Type": "application/json"],
            body: JSONEncoder().encode(DirectConversationMuteRequest(isMuted: isMuted)),
            showToastOnError: false
        )
    }

    private func path(_ id: String) -> String {
        AppConstants.DirectMessages.apiPath + "/" + (id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id)
    }

    private func pageQuery(_ page: Int) -> [URLQueryItem] {
        [URLQueryItem(name: "page", value: String(page)),
         URLQueryItem(name: "size", value: String(AppConstants.DirectMessages.pageSize))]
    }
}
