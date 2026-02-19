//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct TrendingStripPhotoTileView: View {
    let status: Status
    let height: CGFloat
    @AppStorage("settings.alwaysShowNsfw") private var alwaysShowNsfw = false

    private var hiddenPreviewContentWarningText: String? {
        status.contentWarning?.nilIfEmpty
    }

    private var tileWidth: CGFloat {
        let ratio = max(status.firstAttachmentAspectRatio ?? 1.0, 0.6)
        return min(max(height * ratio, 110), 440)
    }

    var body: some View {
        Group {
            if status.shouldHidePreviewImageOnTimelines(alwaysShowNsfw: alwaysShowNsfw) {
                AttachmentBlurHashPlaceholderView(
                    blurHash: status.firstAttachmentBlurHash,
                    cornerRadius: 8,
                    aspectRatio: status.firstAttachmentAspectRatio ?? 1,
                    fixedHeight: height
                )
                .overlay {
                    if let warning = hiddenPreviewContentWarningText {
                        TimelineContentWarningOverlayView(text: warning)
                            .padding(12)
                    }
                }
                .frame(width: tileWidth, height: height)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else if let preview = status.firstAttachmentURL {
                AsyncImage(url: URL(string: preview),
                           transaction: Transaction(animation: .easeInOut(duration: 0.3))) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .transition(.opacity)
                    case .empty, .failure:
                        AttachmentBlurHashPlaceholderView(
                            blurHash: status.firstAttachmentBlurHash,
                            cornerRadius: 8,
                            aspectRatio: status.firstAttachmentAspectRatio ?? 1,
                            fixedHeight: height
                        )
                    @unknown default:
                        AttachmentBlurHashPlaceholderView(
                            blurHash: status.firstAttachmentBlurHash,
                            cornerRadius: 8,
                            aspectRatio: status.firstAttachmentAspectRatio ?? 1,
                            fixedHeight: height
                        )
                    }
                }
                .frame(width: tileWidth, height: height)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.secondary.opacity(0.14))
                    .overlay {
                        Image(systemName: "photo")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: tileWidth, height: height)
            }
        }
    }
}
