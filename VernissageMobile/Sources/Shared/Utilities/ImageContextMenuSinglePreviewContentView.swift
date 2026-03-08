//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import NukeUI
import SwiftUI

struct ImageContextMenuSinglePreviewContentView: View {
    let status: Status
    let attachment: Attachment

    private let previewImageSize: CGFloat = 78

    private var displayName: String {
        status.mainStatus.user?.name?.nilIfEmpty ?? status.mainStatus.user?.userName ?? "Unknown"
    }

    private var userName: String? {
        status.mainStatus.user?.userName?.trimmingPrefix("@").nilIfEmpty
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let imageURLString = attachment.smallImageURL?.nilIfEmpty ?? attachment.orginalImageURL?.nilIfEmpty,
               let imageURL = URL(string: imageURLString) {
                LazyImage(url: imageURL) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.secondary.opacity(0.18))
                    }
                }
                .frame(width: previewImageSize, height: previewImageSize)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    AsyncAvatarView(urlString: status.mainStatus.user?.avatarUrl, size: 24)

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

                if let markdown = status.markdownNote?.nilIfEmpty {
                    MarkdownFormattedTextView(markdown)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .lineLimit(8)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("No text for this status.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
