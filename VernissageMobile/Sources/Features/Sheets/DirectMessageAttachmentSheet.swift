//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct DirectMessageAttachmentSheet: View {
    let selection: DirectMessageAttachmentSelection

    var body: some View {
        StatusAttachmentViewerScreen(attachments: selection.attachments, initialIndex: selection.initialIndex)
    }
}
