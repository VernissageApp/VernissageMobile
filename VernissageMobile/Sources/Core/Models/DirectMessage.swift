//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

struct DirectMessage: Decodable, Identifiable, Sendable {
    let id: String
    let conversationId: String
    var status: Status?
    let author: User?
    let publishedAt: Date?
    var deletedAt: Date?
    let replyToStatusId: String?
    let recipients: [User]
    var readAt: Date?

    var sender: User? {
        author ?? status?.user
    }

    var date: Date? {
        publishedAt ?? status?.displayDate
    }
}
