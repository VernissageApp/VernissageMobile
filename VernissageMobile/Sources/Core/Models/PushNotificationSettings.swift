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
    var directMessageEnabled = true

    enum CodingKeys: String, CodingKey {
        case notificationsEnabled
        case mentionEnabled
        case statusEnabled
        case reblogEnabled
        case followEnabled
        case followRequestEnabled
        case favouriteEnabled
        case updateEnabled
        case adminSignUpEnabled
        case adminReportEnabled
        case newCommentEnabled
        case directMessageEnabled
    }

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        // Older saved subscriptions omit the direct-message preference; keep it enabled by default.
        notificationsEnabled = try values.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? false
        mentionEnabled = try values.decodeIfPresent(Bool.self, forKey: .mentionEnabled) ?? true
        statusEnabled = try values.decodeIfPresent(Bool.self, forKey: .statusEnabled) ?? true
        reblogEnabled = try values.decodeIfPresent(Bool.self, forKey: .reblogEnabled) ?? true
        followEnabled = try values.decodeIfPresent(Bool.self, forKey: .followEnabled) ?? true
        followRequestEnabled = try values.decodeIfPresent(Bool.self, forKey: .followRequestEnabled) ?? true
        favouriteEnabled = try values.decodeIfPresent(Bool.self, forKey: .favouriteEnabled) ?? true
        updateEnabled = try values.decodeIfPresent(Bool.self, forKey: .updateEnabled) ?? true
        adminSignUpEnabled = try values.decodeIfPresent(Bool.self, forKey: .adminSignUpEnabled) ?? true
        adminReportEnabled = try values.decodeIfPresent(Bool.self, forKey: .adminReportEnabled) ?? true
        newCommentEnabled = try values.decodeIfPresent(Bool.self, forKey: .newCommentEnabled) ?? true
        directMessageEnabled = try values.decodeIfPresent(Bool.self, forKey: .directMessageEnabled) ?? true
    }
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
        self.directMessageEnabled = subscription.webPushDirectMessageEnabled ?? true
    }
}
#endif
