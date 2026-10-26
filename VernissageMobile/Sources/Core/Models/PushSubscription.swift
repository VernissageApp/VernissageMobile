//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

struct PushSubscription: Codable, Identifiable {
    var id: String?
    var endpoint: String
    var userAgentPublicKey: String
    var auth: String
    var webPushNotificationsEnabled: Bool
    var webPushMentionEnabled: Bool
    var webPushStatusEnabled: Bool
    var webPushReblogEnabled: Bool
    var webPushFollowEnabled: Bool
    var webPushFollowRequestEnabled: Bool
    var webPushFavouriteEnabled: Bool
    var webPushUpdateEnabled: Bool
    var webPushAdminSignUpEnabled: Bool
    var webPushAdminReportEnabled: Bool
    var webPushNewCommentEnabled: Bool
    var webPushDirectMessageEnabled: Bool?
    var createdAt: Date?
    var updatedAt: Date?
}

extension PushSubscription {
    init(endpoint: String, keyMaterial: WebPushKeyMaterial, settings: PushNotificationSettings, supportsDirectMessages: Bool) {
        self.id = nil
        self.endpoint = endpoint
        self.userAgentPublicKey = keyMaterial.p256dh
        self.auth = keyMaterial.auth
        self.webPushNotificationsEnabled = settings.notificationsEnabled
        self.webPushMentionEnabled = settings.mentionEnabled
        self.webPushStatusEnabled = settings.statusEnabled
        self.webPushReblogEnabled = settings.reblogEnabled
        self.webPushFollowEnabled = settings.followEnabled
        self.webPushFollowRequestEnabled = settings.followRequestEnabled
        self.webPushFavouriteEnabled = settings.favouriteEnabled
        self.webPushUpdateEnabled = settings.updateEnabled
        self.webPushAdminSignUpEnabled = settings.adminSignUpEnabled
        self.webPushAdminReportEnabled = settings.adminReportEnabled
        self.webPushNewCommentEnabled = settings.newCommentEnabled
        self.webPushDirectMessageEnabled = supportsDirectMessages ? settings.directMessageEnabled : nil
        self.createdAt = nil
        self.updatedAt = nil
    }
}
