//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

struct NotificationGroup: Identifiable {
    let notifications: [AppNotification]

    var id: String {
        let notificationKeys = notifications.map(\.uniquenessKey).joined(separator: "|")
        return "group:\(notificationKeys)"
    }

    var representative: AppNotification {
        notifications[0]
    }

    var displayText: String {
        representative.displayText
    }

    var iconName: String {
        representative.iconName
    }

    var latestCreatedAtLabel: String? {
        guard let latestCreatedAt = notifications.compactMap(\.createdAt).max() else {
            return nil
        }

        return "latest \(latestCreatedAt.relativeDateLabel)"
    }

    var linkedStatus: Status? {
        representative.linkedStatus
    }
}
