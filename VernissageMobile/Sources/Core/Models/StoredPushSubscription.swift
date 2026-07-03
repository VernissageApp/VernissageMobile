//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

struct StoredPushSubscription: Codable, Equatable {
    let subscriptionId: String
    var serverSubscriptionId: String?
    var endpoint: String?
    var deviceToken: String?
    var environment: String
    var keyMaterial: WebPushKeyMaterial
    var settings: PushNotificationSettings

    init(subscriptionId: String,
         serverSubscriptionId: String? = nil,
         endpoint: String? = nil,
         deviceToken: String? = nil,
         environment: String,
         keyMaterial: WebPushKeyMaterial,
         settings: PushNotificationSettings) {
        self.subscriptionId = subscriptionId
        self.serverSubscriptionId = serverSubscriptionId
        self.endpoint = endpoint
        self.deviceToken = deviceToken
        self.environment = environment
        self.keyMaterial = keyMaterial
        self.settings = settings
    }
}
