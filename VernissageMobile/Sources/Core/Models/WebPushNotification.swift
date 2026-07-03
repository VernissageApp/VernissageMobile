//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

struct WebPushNotification: Decodable {
    let title: String?
    let body: String?
    let data: WebPushNotificationData?
}
