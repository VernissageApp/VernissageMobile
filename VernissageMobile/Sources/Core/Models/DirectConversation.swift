//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

struct DirectConversation: Decodable, Identifiable, Sendable {
    let id: String
    let participants: [User]
    let lastStatusId: String?
    let summary: String?
    let lastMessageDeletedAt: Date?
    let lastActivityAt: Date
    let hasUnreadMessages: Bool
    let lastReadAt: Date?
    var isMuted: Bool

    func otherParticipants(currentUserID: String?) -> [User] {
        participants.filter { $0.id != currentUserID }
    }

    func title(currentUserID: String?) -> String {
        let users = otherParticipants(currentUserID: currentUserID)
        let name = users.first?.name?.nilIfEmpty ?? users.first?.userName ?? "Conversation"

        return users.count > 1 ? "\(name) +\(users.count - 1)" : name
    }
}
