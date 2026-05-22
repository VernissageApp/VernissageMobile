//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

enum NotificationListItem: Identifiable {
    case notification(AppNotification)
    case group(NotificationGroup)

    var id: String {
        switch self {
        case .notification(let notification):
            return notification.uniquenessKey
        case .group(let group):
            return group.id
        }
    }
}
