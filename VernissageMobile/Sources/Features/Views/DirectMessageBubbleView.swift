//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct DirectMessageBubbleView: View {
    let message: DirectMessage
    let isOwn: Bool
    let isActionPending: Bool
    let onOpenMarkdownURL: (URL) -> OpenURLAction.Result
    let onOpenProfile: (User) -> Void
    let onLike: () -> Void
    let onDelete: () -> Void
    let onOpenAttachment: ([Attachment], Int) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isOwn {
                Spacer(minLength: 36)
            }

            if !isOwn {
                avatar
            }

            VStack(alignment: isOwn ? .trailing : .leading, spacing: 5) {
                if !isOwn {
                    Text(message.sender?.name?.nilIfEmpty ?? message.sender?.userName ?? "Unknown")
                        .font(.caption.weight(.semibold))
                }

                if let date = message.date {
                    Text(date, format: .dateTime.month(.abbreviated).day().hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                content
                    .padding(12)
                    .background(isOwn ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.15),
                                in: .rect(cornerRadius: 18))
                    .contextMenu {
                        if message.deletedAt == nil, message.status != nil {
                            if isOwn {
                                Button("Delete message", systemImage: "trash", role: .destructive, action: onDelete)
                                    .disabled(isActionPending)
                            } else {
                                Button(message.status?.favourited == true ? "Unlike" : "Like",
                                       systemImage: message.status?.favourited == true ? "star.slash" : "star", action: onLike)
                                    .disabled(isActionPending)
                            }
                        }
                    }
                    .accessibilityActions {
                        if message.deletedAt == nil, message.status != nil, !isActionPending {
                            if isOwn {
                                Button("Delete message", action: onDelete)
                            } else {
                                Button(message.status?.favourited == true ? "Unlike" : "Like", action: onLike)
                            }
                        }
                    }

                if message.deletedAt == nil, let count = message.status?.favouritesCount, count > 0 {
                    Label("\(count)", systemImage: message.status?.favourited == true ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundStyle(.tint)
                        .accessibilityLabel("\(count) likes")
                }
            }

            if isOwn {
                avatar
            }

            if !isOwn {
                Spacer(minLength: 36)
            }
        }
    }

    @ViewBuilder
    private var avatar: some View {
        if let sender = message.sender {
            Button {
                onOpenProfile(sender)
            } label: {
                AsyncAvatarView(urlString: sender.avatarUrl, size: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open profile of \(sender.name?.nilIfEmpty ?? sender.userName ?? "Unknown")")
        } else {
            AsyncAvatarView(urlString: nil, size: 32)
                .accessibilityHidden(true)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            if message.deletedAt != nil || message.status == nil {
                Text(AppConstants.DirectMessages.deletedMessage)
                    .italic()
                    .foregroundStyle(.secondary)
            } else if let status = message.status {
                // Use the status HTML-to-Markdown pipeline to preserve formatting, links, and line breaks.
                if let markdown = status.markdownNote?.nilIfEmpty {
                    MarkdownFormattedTextView(markdown)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .environment(\.openURL, OpenURLAction { url in
                            onOpenMarkdownURL(url)
                        })
                } else if status.noteForDisplay?.nilIfEmpty != nil {
                    Text("Cannot render message text.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                let attachments = status.attachments ?? []
                ForEach(attachments.indices, id: \.self) { index in
                    let attachment = attachments[index]
                    Button {
                        onOpenAttachment(attachments, index)
                    } label: {
                        AsyncImage(url: URL(string: attachment.smallImageURL ?? "")) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            Image(systemName: "photo").padding()
                        }
                        .frame(maxWidth: 240, maxHeight: 240)
                        .clipShape(.rect(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(attachment.description?.nilIfEmpty ?? "Open photo")
                }
            }
        }
    }
}
