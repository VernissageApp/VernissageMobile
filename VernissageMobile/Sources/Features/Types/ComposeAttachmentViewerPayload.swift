//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ComposeAttachmentViewerPayload: Identifiable {
    let id = UUID()
    let attachments: [Attachment]
    let initialIndex: Int
    let localImages: [Int: UIImage]
}
