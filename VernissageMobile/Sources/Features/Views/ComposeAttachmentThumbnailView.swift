//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ComposeAttachmentThumbnailView: View {
    private let thumbnailSize: CGFloat = 102

    let attachment: ComposeStatusAttachment
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        attachmentPreview
            .frame(width: thumbnailSize, height: thumbnailSize)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.secondary.opacity(0.25), lineWidth: 1)
            )
            .overlay(alignment: .bottom) {
                HStack(spacing: 6) {
                    Image(systemName: attachment.isAltMissing ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(attachment.isAltMissing ? .red : .green)

                    Text("ALT")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.56), in: Capsule())
                .padding(.bottom, 7)
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                        .background(Circle().fill(.white))
                }
                .buttonStyle(.plain)
                .padding(4)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onTapGesture(perform: onTap)
    }

    @ViewBuilder
    private var attachmentPreview: some View {
        if let localImage = attachment.localImage {
            Image(uiImage: localImage)
                .resizable()
                .scaledToFill()
                .overlay {
                    if attachment.isUploading {
                        ZStack {
                            Color.black.opacity(0.35)
                            ProgressView()
                                .tint(.white)
                        }
                    }
                }
        } else if let remoteImageURL = attachment.remoteImageURL?.nilIfEmpty,
                  let remoteURL = URL(string: remoteImageURL) {
            AsyncImage(url: remoteURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .empty:
                    ProgressView()
                        .tint(.secondary)
                case .failure:
                    AttachmentBlurHashPlaceholderView(
                        blurHash: attachment.blurhash,
                        cornerRadius: 12,
                        aspectRatio: 1,
                        fixedHeight: thumbnailSize
                    )
                @unknown default:
                    AttachmentBlurHashPlaceholderView(
                        blurHash: attachment.blurhash,
                        cornerRadius: 12,
                        aspectRatio: 1,
                        fixedHeight: thumbnailSize
                    )
                }
            }
        } else {
            AttachmentBlurHashPlaceholderView(
                blurHash: attachment.blurhash,
                cornerRadius: 12,
                aspectRatio: 1,
                fixedHeight: thumbnailSize
            )
        }
    }
}
