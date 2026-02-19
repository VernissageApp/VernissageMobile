//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ReblogStatus: Decodable {
    let id: String
    let isLocal: Bool?
    let sensitive: Bool?
    let visibility: String?
    let commentsDisabled: Bool?
    let replyToStatusId: String?
    let note: String?
    let noteHtml: String?
    let url: String?
    let activityPubUrl: String?
    let contentWarning: String?
    let publishedAt: Date?
    let createdAt: Date?
    let repliesCount: Int?
    let reblogsCount: Int?
    let favouritesCount: Int?
    let favourited: Bool?
    let reblogged: Bool?
    let bookmarked: Bool?
    let featured: Bool?
    let user: User?
    let attachments: [Attachment]?
    let category: StatusCategory?
}
extension ReblogStatus {
    var asStatus: Status {
        Status(
            id: id,
            reblog: nil,
            isLocal: isLocal,
            sensitive: sensitive,
            visibility: visibility,
            commentsDisabled: commentsDisabled,
            replyToStatusId: replyToStatusId,
            note: note,
            noteHtml: noteHtml,
            url: url,
            activityPubUrl: activityPubUrl,
            contentWarning: contentWarning,
            publishedAt: publishedAt,
            createdAt: createdAt,
            repliesCount: repliesCount,
            reblogsCount: reblogsCount,
            favouritesCount: favouritesCount,
            favourited: favourited,
            reblogged: reblogged,
            bookmarked: bookmarked,
            featured: featured,
            user: user,
            attachments: attachments,
            category: category
        )
    }
}
