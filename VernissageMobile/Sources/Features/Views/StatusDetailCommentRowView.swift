//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct StatusDetailCommentRowView: View {
    @EnvironmentObject private var appState: AppState

    let comment: Status
    let isIndented: Bool
    let onOpenMarkdownURL: (URL) -> OpenURLAction.Result
    let onToggleFavourite: () -> Void
    let onReply: () -> Void
    let onTranslate: () -> Void
    let onCopyText: () -> Void
    let onReport: () -> Void
    let onDelete: () -> Void

    private var displayName: String {
        comment.user?.name?.nilIfEmpty ?? comment.user?.userName ?? "Unknown"
    }

    private var userName: String? {
        comment.user?.userName?.trimmingPrefix("@").nilIfEmpty
    }

    private var canTranslate: Bool {
        comment.noteForDisplay?.nilIfEmpty != nil
    }

    private var canCopyText: Bool {
        comment.noteForDisplay?.nilIfEmpty != nil
    }

    private var canReport: Bool {
        comment.user?.id?.nilIfEmpty != nil
    }

    private var canDelete: Bool {
        guard let activeUserName = appState.activeAccount?.userName.trimmingPrefix("@").lowercased().nilIfEmpty,
              let commentUserName = comment.user?.userName?.trimmingPrefix("@").lowercased().nilIfEmpty else {
            return false
        }

        return activeUserName == commentUserName
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
                            .foregroundStyle(.gray)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: comment.favourited == true ? "star.fill" : "star")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(comment.favourited == true ? .yellow : .gray)
                        .accessibilityLabel(comment.favourited == true ? "Favourited" : "Not favourited")
                }

                if let markdown = comment.markdownNote?.nilIfEmpty {
                    MarkdownFormattedTextView(markdown)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .environment(\.openURL, OpenURLAction { url in
                            onOpenMarkdownURL(url)
                        })
                } else if let noteForDisplay = comment.noteForDisplay, noteForDisplay.isEmpty == false {
                    Text("Cannot render text comment.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No text for this comment.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    if let createdAt = comment.displayDate {
                        Text(createdAt.relativeDateLabel)
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }

                    Spacer(minLength: 0)

                    Button("Reply") {
                        onReply()
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }
            }
        }
        .padding(.leading, isIndented ? 26 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .contextMenu {
            commentActionsMenuContent
        } preview: {
            commentPreviewContent
        }
    }

    @ViewBuilder
    private var commentActionsMenuContent: some View {
        Button {
            onToggleFavourite()
        } label: {
            Label(comment.favourited == true ? "Unfavourite" : "Favourite", systemImage: comment.favourited == true ? "star.slash" : "star")
        }

        Button {
            onReply()
        } label: {
            Label("Reply", systemImage: "arrowshape.turn.up.left")
        }

        Divider()

        Button {
            onTranslate()
        } label: {
            Label("Translate", systemImage: "translate")
        }
        .disabled(!canTranslate)

        Button {
            onCopyText()
        } label: {
            Label("Copy text", systemImage: "doc.on.doc")
        }
        .disabled(!canCopyText)

        Button {
            onReport()
        } label: {
            Label("Report", systemImage: "flag")
        }
        .disabled(!canReport)

        if canDelete {
            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var commentPreviewContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                AsyncAvatarView(urlString: comment.user?.avatarUrl, size: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let userName {
                        Text("@\(userName)")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                            .lineLimit(1)
                    }
                }
            }

            if let markdown = comment.markdownNote?.nilIfEmpty {
                MarkdownFormattedTextView(markdown)
                    .font(.body)
                    .lineLimit(10)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .environment(\.openURL, OpenURLAction { url in
                        onOpenMarkdownURL(url)
                    })
            } else {
                Text("No text for this comment.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(width: 340, alignment: .leading)
        .frame(minHeight: 150, alignment: .topLeading)
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
