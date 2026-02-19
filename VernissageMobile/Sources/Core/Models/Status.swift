//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct Status: Decodable, Identifiable {
    let id: String
    let reblog: ReblogStatus?
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

    enum CodingKeys: String, CodingKey {
        case id
        case reblog
        case isLocal
        case sensitive
        case visibility
        case commentsDisabled
        case replyToStatusId
        case note
        case noteHtml
        case url
        case activityPubUrl
        case contentWarning
        case publishedAt
        case createdAt
        case repliesCount
        case reblogsCount
        case favouritesCount
        case favourited
        case reblogged
        case bookmarked
        case featured
        case user
        case attachments
        case category
    }
}
extension Status {
    var mainStatus: Status {
        reblog?.asStatus ?? self
    }

    func shouldHidePreviewImageOnTimelines(alwaysShowNsfw: Bool) -> Bool {
        guard alwaysShowNsfw == false else {
            return false
        }

        return mainStatus.sensitive == true && mainStatus.primaryAttachment != nil
    }

    var displayDate: Date? {
        mainStatus.publishedAt ?? mainStatus.createdAt
    }

    var shareURL: String? {
        let status = mainStatus

        if let activityPubUrl = status.activityPubUrl?.nilIfEmpty {
            return activityPubUrl
        }

        if let url = status.url?.nilIfEmpty {
            return url
        }

        guard let profileURL = status.user?.url?.nilIfEmpty else {
            return nil
        }

        let normalizedProfileURL = profileURL.replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
        return "\(normalizedProfileURL)/\(status.id)"
    }

    var firstAttachmentURL: String? {
        primaryAttachment?.smallImageURL
    }

    var hasAttachment: Bool {
        primaryAttachment != nil
    }

    var primaryAttachment: Attachment? {
        let attachments = mainStatus.attachments
        return attachments?.first(where: { $0.smallImageURL != nil }) ?? attachments?.first
    }

    var firstAttachmentBlurHash: String? {
        primaryAttachment?.blurhash?.nilIfEmpty
    }

    var firstAttachmentAspectRatio: CGFloat? {
        primaryAttachment?.aspectRatio
    }
    
    var hasMultipleAttachments: Bool {
        mainStatus.attachments?.count ?? 0 > 1
    }

    var imageAttachmentsCount: Int {
        (mainStatus.attachments ?? []).filter { $0.smallImageURL != nil || $0.orginalImageURL != nil }.count
    }

    var noteForDisplay: String? {
        let status = mainStatus

        if status.isLocal == true {
            return status.noteHtml?.nilIfEmpty ?? status.note?.nilIfEmpty
        }

        return status.note?.nilIfEmpty ?? status.noteHtml?.nilIfEmpty
    }

    var markdownNote: String? {
        guard let noteForDisplay = noteForDisplay else {
            return nil
        }

        let markdown = try? noteForDisplay.parseToMarkdown()
        return markdown?.nilIfEmpty
    }
}
