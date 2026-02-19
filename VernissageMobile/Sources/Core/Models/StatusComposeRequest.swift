//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct StatusComposeRequest: Encodable {
    let id: String?
    let note: String
    let visibility: String
    let sensitive: Bool
    let contentWarning: String?
    let commentsDisabled: Bool
    let replyToStatusId: String?
    let attachmentIds: [String]
    let categoryId: String?
}
