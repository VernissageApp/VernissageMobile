//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct SearchStatusRowView: View {
    let status: Status

    var body: some View {
        if status.hasAttachment {
            VStack(alignment: .leading, spacing: 8) {
                TimelinePhotoTileView(status: status)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                if let markdown = status.markdownNote?.nilIfEmpty {
                    MarkdownFormattedTextView(markdown)
                        .font(.body)
                        .foregroundStyle(.primary)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    AsyncAvatarView(urlString: status.user?.avatarUrl)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(status.user?.name?.nilIfEmpty ?? status.user?.userName ?? "Unknown")
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if let userName = status.user?.userName?.nilIfEmpty {
                            Text("@\(userName.trimmingPrefix("@"))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                if let markdown = status.markdownNote?.nilIfEmpty {
                    MarkdownFormattedTextView(markdown)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(4)
                } else if let noteForDisplay = status.noteForDisplay, noteForDisplay.isEmpty == false {
                    Text("Cannot render text status.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No text for this status.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
