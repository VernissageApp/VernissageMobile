//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct StatusDetailCommentRowView: View {
    let comment: Status
    let isIndented: Bool
    let onReply: () -> Void

    private var displayName: String {
        comment.user?.name?.nilIfEmpty ?? comment.user?.userName ?? "Unknown"
    }

    private var userName: String? {
        comment.user?.userName?.trimmingPrefix("@").nilIfEmpty
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let userName {
                NavigationLink {
                    UserProfileScreen(userName: userName, preferredDisplayName: displayName)
                } label: {
                    AsyncAvatarView(urlString: comment.user?.avatarUrl, size: 42)
                }
                .buttonStyle(.plain)
            } else {
                AsyncAvatarView(urlString: comment.user?.avatarUrl, size: 42)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let userName {
                        Text("@\(userName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Button("Reply") {
                        onReply()
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }

                if let markdown = comment.markdownNote?.nilIfEmpty {
                    MarkdownFormattedTextView(markdown)
                        .font(.body)
                        .foregroundStyle(.primary)
                } else if let noteForDisplay = comment.noteForDisplay, noteForDisplay.isEmpty == false {
                    Text("Cannot render text comment.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No text for this comment.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                if let createdAt = comment.displayDate {
                    Text(createdAt.relativeDateLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.leading, isIndented ? 26 : 0)
    }
}
