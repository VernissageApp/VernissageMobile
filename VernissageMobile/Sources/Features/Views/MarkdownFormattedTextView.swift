//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI
import EmojiText

struct MarkdownFormattedTextView: View {
    private let markdown: String

    init(_ markdown: String) {
        self.markdown = markdown
    }

    var body: some View {
        EmojiText(markdown: markdown, emojis: [])
    }
}
