//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

struct DirectMessageRequest: Encodable {
    let recipientIds: [String]
    let note: String
    let attachmentIds: [String]
}
