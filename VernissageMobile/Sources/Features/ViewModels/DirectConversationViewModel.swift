//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation
import Observation

@MainActor
@Observable
final class DirectConversationViewModel {
    private(set) var conversation: DirectConversation?
    private(set) var messages: [DirectMessage] = []
    private(set) var recipients: [User] = []
    private(set) var currentUserID: String?
    private(set) var searchResults: [User] = []
    private(set) var attachments: [UploadedAttachment] = []
    private(set) var isPreparing = false
    private(set) var isLoading = false
    private(set) var isSending = false
    private(set) var isUploading = false
    private(set) var isMuting = false
    private(set) var pendingActions: Set<String> = []
    private(set) var hasMore = false
    private(set) var isReady = false
    private(set) var emailVerified = false
    private(set) var scrollRequest = 0

    var note = ""
    var userQuery = ""
    var errorMessage: String?
    var visibleMessageIDs: [String] = []

    private let initialConversationID: String?
    private var page = 0
    private var accountID: UUID?
    private var sessionAccount: StoredAccount?
    private var reading = false
    private var contentRevision = 0

    init(conversation: DirectConversation?, conversationID: String? = nil) {
        self.conversation = conversation
        self.initialConversationID = conversationID
    }

    var isDraft: Bool {
        conversation == nil && initialConversationID == nil
    }

    var isBusy: Bool {
        isSending || isUploading
    }

    var title: String {
        conversation?.title(currentUserID: currentUserID) ?? (isDraft ? "New conversation" : "Conversation")
    }

    var recipientMentions: String {
        let mentions = recipients.compactMap { user -> String? in
            let account = user.isLocal == false
                ? user.account?.nilIfEmpty ?? user.userName?.nilIfEmpty
                : user.userName?.nilIfEmpty ?? user.account?.nilIfEmpty

            guard let account else {
                return nil
            }

            return "@\(account.trimmingPrefix("@"))"
        }

        return mentions.isEmpty ? "" : mentions.joined(separator: " ") + " "
    }

    var readTaskKey: String {
        messages.filter { visibleMessageIDs.contains($0.id) && $0.readAt == nil }
            .map(\.id)
            .sorted()
            .joined(separator: ",")
    }

    func canSend(using appState: AppState) -> Bool {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasMessageText = !trimmedNote.isEmpty
            && trimmedNote != recipientMentions.trimmingCharacters(in: .whitespacesAndNewlines)

        return isReady && emailVerified && !isBusy && !isLoading && !recipients.isEmpty
            && (hasMessageText || !attachments.isEmpty)
            && note.count <= maxCharacters(using: appState)
    }

    func maxCharacters(using appState: AppState) -> Int {
        appState.activeInstanceDetails?.configuration?.statuses?.maxCharacters ?? AppConstants.DirectMessages.defaultMaxCharacters
    }

    func maxAttachments(using appState: AppState) -> Int {
        appState.activeInstanceDetails?.configuration?.statuses?.maxMediaAttachments ?? AppConstants.DirectMessages.defaultMaxAttachments
    }

    private func isCurrent(_ appState: AppState) -> Bool {
        // Ignore asynchronous results after the user switches to another account.
        accountID != nil && appState.activeAccountID == accountID
    }

    func prepare(using appState: AppState) async {
        guard !isReady, !isPreparing, let account = appState.activeAccount else {
            return
        }

        accountID = account.id
        sessionAccount = account
        isPreparing = true

        defer {
            isPreparing = false
        }

        do {
            let user = try await appState.api.users.fetchProfile(for: account)

            guard isCurrent(appState), !Task.isCancelled else {
                return
            }

            currentUserID = user.id

            // Notification links provide only an ID, so resolve the conversation before deriving its recipients.
            if conversation == nil, let initialConversationID {
                let loaded = try await appState.api.directMessages.conversation(id: initialConversationID)

                guard isCurrent(appState), !Task.isCancelled else {
                    return
                }

                conversation = loaded
            }

            let previousMentions = recipientMentions
            recipients = conversation?.otherParticipants(currentUserID: user.id) ?? []
            updateRecipientMentions(previousMentions: previousMentions)

            let verified = try await appState.api.account.emailVerified()

            guard isCurrent(appState), !Task.isCancelled else {
                return
            }

            emailVerified = verified.result

            if conversation != nil {
                await loadMessages(using: appState)
            }

            guard isCurrent(appState), !Task.isCancelled else {
                return
            }

            isReady = conversation == nil || page > 0
        } catch {
            report(error, using: appState)
        }
    }

    func searchUsers(using appState: AppState) async {
        searchResults = []
        let query = userQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isDraft, isReady, !query.isEmpty, isCurrent(appState) else {
            return
        }

        do {
            try await Task.sleep(for: .milliseconds(300))
            let result = try await appState.api.search.search(query: query, type: "users")

            // Discard results if the query or active account changed while the request was in flight.
            guard !Task.isCancelled, isCurrent(appState), query == userQuery.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return
            }

            searchResults = (result.users ?? []).filter { user in
                user.id != nil && user.id != currentUserID && !recipients.contains(where: { $0.id == user.id })
            }
        } catch {
            report(error, using: appState)
        }
    }

    func addRecipient(_ user: User) {
        guard isDraft, !isBusy, recipients.count < AppConstants.DirectMessages.maximumRecipients,
              let id = user.id, id != currentUserID, !recipients.contains(where: { $0.id == id }) else {
            return
        }

        let previousMentions = recipientMentions
        recipients.append(user)
        updateRecipientMentions(previousMentions: previousMentions)

        userQuery = ""
        searchResults = []
    }

    func removeRecipient(_ user: User) {
        guard isDraft, !isBusy else {
            return
        }

        let previousMentions = recipientMentions
        recipients.removeAll { $0.id == user.id }
        updateRecipientMentions(previousMentions: previousMentions)
    }

    private func updateRecipientMentions(previousMentions: String) {
        // Replace only the automatic prefix, preserving the draft and any manually edited mentions.
        guard note.hasPrefix(previousMentions) else {
            return
        }

        note = recipientMentions + note.dropFirst(previousMentions.count)
    }

    func loadMessages(using appState: AppState, more: Bool = false, reportErrors: Bool = true) async {
        guard !isLoading, !isSending, pendingActions.isEmpty, !more || hasMore, let conversation, isCurrent(appState) else {
            return
        }

        isLoading = true
        let revision = contentRevision

        defer {
            isLoading = false
        }

        do {
            let nextPage = more ? page + 1 : 1
            let result = try await appState.api.directMessages.messages(id: conversation.id, page: nextPage)

            // Reject history snapshots fetched before a local like or deletion started.
            guard isCurrent(appState), !Task.isCancelled, revision == contentRevision else {
                return
            }

            var fetchedMessages = result.data
            var refreshedPage = result

            // Bridge all new pages back to known history after long pauses in background polling.
            if !more, let latestKnownID = messages.last?.id {
                var refreshPage = 1

                while refreshedPage.hasMore && !fetchedMessages.contains(where: { $0.id == latestKnownID }) {
                    guard isCurrent(appState), !Task.isCancelled, revision == contentRevision else {
                        return
                    }

                    refreshPage += 1
                    refreshedPage = try await appState.api.directMessages.messages(id: conversation.id, page: refreshPage)

                    guard isCurrent(appState), !Task.isCancelled, revision == contentRevision else {
                        return
                    }

                    let fetchedIDs = Set(fetchedMessages.map(\.id))
                    fetchedMessages.append(contentsOf: refreshedPage.data.filter { !fetchedIDs.contains($0.id) })
                }
            }

            // The API returns newest messages first; the chat displays them in chronological order.
            let incoming = fetchedMessages.reversed()
            let ids = Set(fetchedMessages.map(\.id))

            if more {
                // New arrivals can shift page boundaries, so remove overlapping IDs before prepending older messages.
                messages = incoming + messages.filter { !ids.contains($0.id) }
                page = nextPage
                hasMore = result.hasMore
            } else {
                // Keep already loaded history while replacing refreshed messages and tombstones.
                messages = messages.filter { !ids.contains($0.id) } + incoming
                messages.sort { ($0.date ?? .distantPast, $0.id) < ($1.date ?? .distantPast, $1.id) }

                hasMore = messages.count < result.total
                page = max(page, 1)
            }
        } catch {
            if reportErrors {
                report(error, using: appState)
            }
        }
    }

    func send(using appState: AppState) async {
        guard canSend(using: appState), isCurrent(appState) else {
            return
        }

        isSending = true

        defer {
            isSending = false
        }

        let request = DirectMessageRequest(
            recipientIds: recipients.compactMap(\.id),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            attachmentIds: attachments.map(\.id)
        )

        do {
            let message = try await appState.api.directMessages.send(request, conversationID: conversation?.id)

            guard isCurrent(appState) else {
                return
            }

            // Restore the recipient prefix only after a successful send so failures preserve the draft and uploaded media.
            note = recipientMentions
            attachments = []
            messages.removeAll { $0.id == message.id }
            messages.append(message)

            if conversation == nil {
                // Lock the audience immediately after the first successful send.
                conversation = DirectConversation(
                    id: message.conversationId,
                    participants: [message.sender].compactMap { $0 } + message.recipients,
                    lastStatusId: message.id, summary: message.status?.note, lastMessageDeletedAt: nil,
                    lastActivityAt: message.date ?? .now, hasUnreadMessages: false, lastReadAt: nil, isMuted: false
                )
            }

            scrollRequest += 1
        } catch {
            report(error, using: appState)
        }
    }

    func toggleLike(_ message: DirectMessage, using appState: AppState) async {
        guard let status = message.status, message.deletedAt == nil, message.sender?.id != currentUserID,
              isCurrent(appState), pendingActions.insert(message.id).inserted else {
            return
        }

        contentRevision += 1

        defer {
            pendingActions.remove(message.id)
        }

        do {
            let updated = try await appState.api.statuses.updateStatusInteraction(
                statusId: message.id, action: status.favourited == true ? .unfavourite : .favourite
            )

            guard isCurrent(appState), let index = messages.firstIndex(where: { $0.id == message.id }),
                  messages[index].deletedAt == nil else {
                return
            }

            messages[index].status = updated
        } catch {
            report(error, using: appState)
        }
    }

    func delete(_ message: DirectMessage, using appState: AppState) async {
        guard message.sender?.id == currentUserID, message.deletedAt == nil, isCurrent(appState),
              pendingActions.insert(message.id).inserted else {
            return
        }

        contentRevision += 1

        defer {
            pendingActions.remove(message.id)
        }

        do {
            try await appState.api.statuses.deleteStatus(statusId: message.id)

            guard isCurrent(appState), let index = messages.firstIndex(where: { $0.id == message.id }) else {
                return
            }

            // Preserve a tombstone in the history until the next refresh supplies the server's deleted entry.
            messages[index].deletedAt = .now
            messages[index].status = nil
        } catch {
            report(error, using: appState)
        }
    }

    func markVisibleRead(using appState: AppState) async {
        guard !reading, let conversation, isCurrent(appState) else {
            return
        }

        // Opening a conversation does not mark incoming messages outside the visible history as read.
        let ids = messages.filter {
            visibleMessageIDs.contains($0.id) && $0.sender?.id != currentUserID
                && $0.deletedAt == nil && $0.status != nil && $0.readAt == nil
        }.map(\.id)

        guard !ids.isEmpty else {
            return
        }

        reading = true

        defer {
            reading = false
        }

        do {
            // Split visible IDs into batches to respect the server's per-request limit.
            for start in stride(from: 0, to: ids.count, by: AppConstants.DirectMessages.maximumReadBatchSize) {
                guard isCurrent(appState), !Task.isCancelled else {
                    return
                }

                let end = min(start + AppConstants.DirectMessages.maximumReadBatchSize, ids.count)
                try await appState.api.directMessages.markRead(id: conversation.id, statusIDs: Array(ids[start..<end]))
            }

            guard isCurrent(appState) else {
                return
            }

            for index in messages.indices where ids.contains(messages[index].id) {
                messages[index].readAt = .now
            }
        } catch {
            report(error, using: appState)
        }
    }

    func toggleMute(using appState: AppState) async {
        guard let conversation, !isMuting, isCurrent(appState) else {
            return
        }

        isMuting = true

        defer {
            isMuting = false
        }

        do {
            try await appState.api.directMessages.mute(id: conversation.id, isMuted: !conversation.isMuted)

            guard isCurrent(appState) else {
                return
            }

            self.conversation?.isMuted = !conversation.isMuted
        } catch {
            report(error, using: appState)
        }
    }

    func upload(data: Data, fileName: String, mimeType: String, using appState: AppState) async {
        guard !isBusy, isCurrent(appState), emailVerified, let account = appState.activeAccount,
              attachments.count < maxAttachments(using: appState) else {
            return
        }

        let supportedTypes = appState.activeInstanceDetails?.configuration?.attachments?.supportedMimeTypes
            ?? AppConstants.DirectMessages.supportedImageMimeTypes

        guard supportedTypes.contains(mimeType) else {
            errorMessage = "This image format is not supported by the instance."
            return
        }

        let limit = appState.activeInstanceDetails?.configuration?.attachments?.imageSizeLimit ?? AppConstants.DirectMessages.defaultImageSizeLimit

        guard data.count <= limit else {
            errorMessage = "The selected image is too large."
            return
        }

        isUploading = true

        defer {
            isUploading = false
        }

        do {
            let uploaded = try await appState.api.attachments.uploadAttachment(imageData: data, fileName: fileName, mimeType: mimeType)

            if !isCurrent(appState) || Task.isCancelled {
                // Cleanup must survive cancellation of the photo picker task.
                Task {
                    try? await appState.api.attachments.deleteAttachment(attachmentId: uploaded.id, for: account,
                                                                        showToastOnError: false)
                }

                return
            }

            attachments.append(uploaded)
        } catch {
            report(error, using: appState)
        }
    }

    func removeAttachment(_ attachment: UploadedAttachment, using appState: AppState) async {
        guard !isBusy, isCurrent(appState) else {
            return
        }

        isUploading = true

        defer {
            isUploading = false
        }

        do {
            try await appState.api.attachments.deleteAttachment(attachmentId: attachment.id)

            guard isCurrent(appState) else {
                return
            }

            attachments.removeAll { $0.id == attachment.id }
        } catch {
            report(error, using: appState)
        }
    }

    func discardAttachments(using appState: AppState) async {
        guard !isSending, let account = sessionAccount else {
            return
        }

        let discarded = attachments
        attachments = []

        // Delete drafts using their original account even if another account is now active.
        for attachment in discarded {
            try? await appState.api.attachments.deleteAttachment(attachmentId: attachment.id, for: account,
                                                                showToastOnError: false)
        }
    }

    private func report(_ error: Error, using appState: AppState) {
        guard !Task.isCancelled, isCurrent(appState), !(error is CancellationError) else {
            return
        }

        errorMessage = error.localizedDescription
    }
}
