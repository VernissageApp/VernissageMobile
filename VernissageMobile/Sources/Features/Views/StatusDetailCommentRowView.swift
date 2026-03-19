//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct StatusDetailCommentRowView: View {
    @Environment(AppState.self) private var appState

    private let maxVisibleAttachments = 3
    private let attachmentThumbnailSize: CGFloat = 64

    let comment: Status
    let isIndented: Bool
    let onOpenMarkdownURL: (URL) -> OpenURLAction.Result
    let onOpenAttachmentViewer: ([Attachment], Int) -> Void
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

    private var commentDisplayableAttachments: [Attachment] {
        let attachments = comment.mainStatus.attachments ?? []
        let withImages = attachments.filter { $0.smallImageURL != nil }

        if withImages.isEmpty, let primaryAttachment = comment.mainStatus.primaryAttachment {
            return [primaryAttachment]
        }

        return withImages
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

                if !commentDisplayableAttachments.isEmpty {
                    commentAttachmentsSection
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

    private var commentAttachmentsSection: some View {
        HStack(alignment: .center, spacing: 6) {
            ForEach(0..<min(commentDisplayableAttachments.count, maxVisibleAttachments), id: \.self) { index in
                let attachment = commentDisplayableAttachments[index]
                Button {
                    onOpenAttachmentViewer(commentDisplayableAttachments, index)
                } label: {
                    commentAttachmentThumbnail(for: attachment)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open comment attachment \(index + 1)")
                .accessibilityHint("Shows comment attachments in full screen")
            }

            if commentDisplayableAttachments.count > maxVisibleAttachments {
                Text("more...")
                    .font(.caption2)
                    .foregroundStyle(.gray)
            }
        }
    }

    @ViewBuilder
    private func commentAttachmentThumbnail(for attachment: Attachment) -> some View {
        if let imageURL = attachment.smallImageURL,
           let remoteURL = URL(string: imageURL) {
            AsyncImage(url: remoteURL, transaction: Transaction(animation: .easeInOut(duration: 0.25))) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .empty, .failure:
                    AttachmentBlurHashPlaceholderView(
                        blurHash: attachment.blurhash,
                        cornerRadius: 8,
                        aspectRatio: 1,
                        fixedHeight: attachmentThumbnailSize
                    )
                @unknown default:
                    AttachmentBlurHashPlaceholderView(
                        blurHash: attachment.blurhash,
                        cornerRadius: 8,
                        aspectRatio: 1,
                        fixedHeight: attachmentThumbnailSize
                    )
                }
            }
            .frame(width: attachmentThumbnailSize, height: attachmentThumbnailSize)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.secondary.opacity(0.24), lineWidth: 1)
            )
        } else {
            AttachmentBlurHashPlaceholderView(
                blurHash: attachment.blurhash,
                cornerRadius: 8,
                aspectRatio: 1,
                fixedHeight: attachmentThumbnailSize
            )
            .frame(width: attachmentThumbnailSize, height: attachmentThumbnailSize)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.secondary.opacity(0.24), lineWidth: 1)
            )
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
