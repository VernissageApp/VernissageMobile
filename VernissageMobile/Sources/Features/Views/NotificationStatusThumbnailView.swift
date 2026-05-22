//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct NotificationStatusThumbnailView: View {
    let status: Status
    var size: CGFloat = 74

    var body: some View {
        NavigationLink {
            StatusDetailScreen(status: status)
        } label: {
            if let imageURL = status.firstAttachmentURL {
                AsyncImage(url: URL(string: imageURL),
                           transaction: Transaction(animation: .easeInOut(duration: 0.3))) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .transition(.opacity)
                    case .empty, .failure:
                        AttachmentBlurHashPlaceholderView(blurHash: status.firstAttachmentBlurHash,
                                                          cornerRadius: 10,
                                                          aspectRatio: 1,
                                                          fixedHeight: size)
                    @unknown default:
                        AttachmentBlurHashPlaceholderView(blurHash: status.firstAttachmentBlurHash,
                                                          cornerRadius: 10,
                                                          aspectRatio: 1,
                                                          fixedHeight: size)
                    }
                }
                .frame(width: size, height: size)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.white.opacity(0.08))
                    .overlay {
                        Image(systemName: "photo")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: size, height: size)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(.white.opacity(0.14), lineWidth: 1)
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open related photo")
    }
}
