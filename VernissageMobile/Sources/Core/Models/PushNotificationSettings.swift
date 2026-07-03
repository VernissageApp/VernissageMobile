//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

struct PushNotificationSettings: Codable, Equatable {
    var notificationsEnabled = false
    var mentionEnabled = true
    var statusEnabled = true
    var reblogEnabled = true
    var followEnabled = true
    var followRequestEnabled = true
    var favouriteEnabled = true
    var updateEnabled = true
    var adminSignUpEnabled = true
    var adminReportEnabled = true
    var newCommentEnabled = true
}

#if !NOTIFICATION_SERVICE_EXTENSION
extension PushNotificationSettings {
    init(subscription: PushSubscription) {
        self.notificationsEnabled = subscription.webPushNotificationsEnabled
        self.mentionEnabled = subscription.webPushMentionEnabled
        self.statusEnabled = subscription.webPushStatusEnabled
        self.reblogEnabled = subscription.webPushReblogEnabled
        self.followEnabled = subscription.webPushFollowEnabled
        self.followRequestEnabled = subscription.webPushFollowRequestEnabled
        self.favouriteEnabled = subscription.webPushFavouriteEnabled
        self.updateEnabled = subscription.webPushUpdateEnabled
        self.adminSignUpEnabled = subscription.webPushAdminSignUpEnabled
        self.adminReportEnabled = subscription.webPushAdminReportEnabled
        self.newCommentEnabled = subscription.webPushNewCommentEnabled
    }
}
#endif
