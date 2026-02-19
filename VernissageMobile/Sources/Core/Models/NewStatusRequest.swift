//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct NewStatusRequest: Encodable {
    let note: String
    let replyToStatusId: String?
    let visibility = StatusVisibility.public;
    let sensitive = false;
    let commentsDisabled = false;
    let attachmentIds: [String] = [];
}
