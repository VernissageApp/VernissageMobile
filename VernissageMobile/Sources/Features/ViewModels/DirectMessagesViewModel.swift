//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation
import Observation

@MainActor
@Observable
final class DirectMessagesViewModel {
    private(set) var conversations: [DirectConversation] = []
    private(set) var currentUserID: String?
    private(set) var isLoading = false
    private(set) var hasMore = false
    private(set) var didLoad = false
    var query = ""
    var errorMessage: String?
    private var page = 0
    private var accountID: UUID?

    var filteredConversations: [DirectConversation] {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)

        return conversations.filter { conversation in
            search.isEmpty || ([conversation.summary ?? ""] + conversation.participants.flatMap {
                [$0.name ?? "", $0.userName ?? "", $0.account ?? ""]
            }).contains { $0.localizedStandardContains(search) }
        }
    }

    func load(using appState: AppState, more: Bool = false) async {
        guard !isLoading, !more || hasMore, let account = appState.activeAccount else {
            return
        }

        accountID = account.id
        isLoading = true

        defer {
            isLoading = false
        }

        do {
            if currentUserID == nil {
                let user = try await appState.api.users.fetchProfile(for: account)

                guard !Task.isCancelled, appState.activeAccountID == accountID else {
                    return
                }

                currentUserID = user.id
            }

            let nextPage = more ? page + 1 : 1
            let result = try await appState.api.directMessages.conversations(page: nextPage)

            guard !Task.isCancelled, appState.activeAccountID == accountID else {
                return
            }

            let incoming = Set(result.data.map(\.id))
            conversations = more ? conversations.filter { !incoming.contains($0.id) } + result.data : result.data
            page = nextPage
            hasMore = result.hasMore
            didLoad = true
        } catch {
            guard !Task.isCancelled, appState.activeAccountID == accountID else {
                return
            }

            errorMessage = error.localizedDescription
            didLoad = true
        }
    }

    func refresh(using appState: AppState) async {
        guard !isLoading, let accountID, appState.activeAccountID == accountID else {
            return
        }

        // Retry incomplete initial loads before merging subsequent inbox updates.
        guard page > 0, currentUserID != nil else {
            await load(using: appState)
            return
        }

        isLoading = true

        defer {
            isLoading = false
        }

        do {
            let result = try await appState.api.directMessages.conversations(page: 1)

            guard !Task.isCancelled, appState.activeAccountID == accountID else {
                return
            }

            let incoming = Set(result.data.map(\.id))
            // Replace refreshed entries while retaining older pages, then restore the inbox's activity order.
            conversations = (result.data + conversations.filter { !incoming.contains($0.id) })
                .sorted { $0.lastActivityAt > $1.lastActivityAt }

            if page <= 1 {
                hasMore = result.hasMore
            }
        } catch {
            // Background refresh retries while the inbox remains visible.
        }
    }
}
