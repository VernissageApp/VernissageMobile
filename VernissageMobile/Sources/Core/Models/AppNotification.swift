//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct AppNotification: Decodable {
    let id: String?
    let notificationType: String?
    let byUser: User?
    let status: Status?
    let mainStatus: Status?
    let createdAt: Date?
    let conversationId: String?
}
extension AppNotification {
    var typedNotificationType: AppNotificationType? {
        guard let notificationType = notificationType?.nilIfEmpty else {
            return nil
        }

        return AppNotificationType(rawValue: notificationType)
    }

    var linkedStatus: Status? {
        // Conversation notifications open the chat instead of exposing a direct message through public status navigation.
        guard conversationId == nil else {
            return nil
        }

        if let mainStatus, mainStatus.hasAttachment {
            return mainStatus
        }

        if let status, status.hasAttachment {
            return status
        }

        if let mainStatus {
            return mainStatus
        }

        return status
    }

    var displayText: String {
        switch typedNotificationType {
        case .mention:
            return "mentioned you"
        case .status:
            return "published photo"
        case .reblog:
            return "boost your photo"
        case .follow:
            return "followed you"
        case .followRequest:
            return "want to follow you"
        case .favourite:
            if conversationId != nil {
                return "favourited your direct message"
            } else if mainStatus == nil {
                return "favourited your photo"
            } else {
                return "favourited your comment"
            }
        case .update:
            return "edited photo"
        case .adminSignUp:
            return "is a new user"
        case .adminReport:
            return "has been reported"
        case .directMessage:
            return "sent you a direct message"
        case .newComment:
            return "wrote new comment"
        case .none:
            return "sent notification"
        }
    }

    var iconName: String {
        switch typedNotificationType {
        case .mention:
            return "at"
        case .status:
            return "sparkles"
        case .reblog:
            return "arrow.2.squarepath"
        case .follow:
            return "person.badge.plus"
        case .followRequest:
            return "person.crop.circle.badge.questionmark"
        case .favourite:
            return "star.fill"
        case .update:
            return "square.and.pencil"
        case .adminSignUp:
            return "person.crop.rectangle.stack.badge.plus"
        case .adminReport:
            return "exclamationmark.bubble"
        case .directMessage, .newComment:
            return "bubble.left.and.bubble.right"
        case .none:
            return "bell"
        }
    }

    var iconColor: Color {
        switch typedNotificationType {
        case .mention:
            return .mint
        case .status:
            return .blue
        case .reblog:
            return .indigo
        case .follow:
            return .green
        case .followRequest:
            return .teal
        case .favourite:
            return .orange
        case .update:
            return .cyan
        case .adminSignUp:
            return .purple
        case .adminReport:
            return .red
        case .directMessage, .newComment:
            return .pink
        case .none:
            return .blue
        }
    }

    var uniquenessKey: String {
        if let id = id?.nilIfEmpty {
            return "id:\(id)"
        }

        let userKey = byUser?.uniquenessKey ?? "unknown-user"
        let dateKey = createdAt?.timeIntervalSince1970 ?? 0
        let typeKey = notificationType ?? "unknown-type"
        return "\(typeKey)|\(userKey)|\(dateKey)"
    }
}
