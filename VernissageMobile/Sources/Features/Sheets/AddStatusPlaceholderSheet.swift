//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct AddStatusPlaceholderSheet: View {
    var initialAttachmentURLs: [URL] = []
    var onDismissRequested: (() -> Void)? = nil

    var body: some View {
        StatusComposeScreen(
            mode: .create,
            initialAttachmentURLs: initialAttachmentURLs,
            onDismissRequested: onDismissRequested
        )
    }
}
