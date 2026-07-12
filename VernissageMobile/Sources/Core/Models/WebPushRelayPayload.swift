//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

struct WebPushRelayPayload: Decodable {
    let encoding: String
    let message: String
    let salt: String?
    let serverPublicKey: String?
    let subscriptionId: String?

    enum CodingKeys: String, CodingKey {
        case encoding = "e"
        case message = "m"
        case salt = "s"
        case serverPublicKey = "k"
        case subscriptionId = "i"
    }
}
