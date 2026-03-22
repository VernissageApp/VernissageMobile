//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ComposeAttachmentViewerScreen: View {
    @Environment(\.dismiss) private var dismiss

    let attachments: [Attachment]
    let initialIndex: Int
    let localImages: [Int: UIImage]

    @State private var selectedIndex: Int

    init(attachments: [Attachment], initialIndex: Int, localImages: [Int: UIImage]) {
        self.attachments = attachments
        self.initialIndex = initialIndex
        self.localImages = localImages

        let maxIndex = max(attachments.count - 1, 0)
        _selectedIndex = State(initialValue: min(max(initialIndex, 0), maxIndex))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if attachments.isEmpty {
                ContentUnavailableView("No photo", systemImage: "photo")
                    .foregroundStyle(.white.opacity(0.8))
            } else {
                TabView(selection: $selectedIndex) {
                    ForEach(attachments.indices, id: \.self) { index in
                        attachmentContent(for: attachments[index], index: index)
                            .tag(index)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 24)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: attachments.count > 1 ? .automatic : .never))
                .indexViewStyle(.page(backgroundDisplayMode: .interactive))
            }

            VStack(spacing: 0) {
                HStack {
                    Spacer(minLength: 0)

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32, weight: .regular))
                            .foregroundStyle(.white.opacity(0.92))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 16)
                    .padding(.top, 10)
                    .accessibilityLabel("Close photo preview")
                }

                Spacer(minLength: 0)
            }
        }
        .statusBarHidden()
    }

    @ViewBuilder
    private func attachmentContent(for attachment: Attachment, index: Int) -> some View {
        if let localImage = localImages[index] {
            Image(uiImage: localImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let imageURLString = attachment.orginalImageURL,
                  let imageURL = URL(string: imageURLString) {
            AsyncImage(url: imageURL,
                       transaction: Transaction(animation: .easeInOut(duration: 0.2))) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .empty, .failure:
                    AttachmentBlurHashPlaceholderView(
                        blurHash: attachment.blurhash,
                        cornerRadius: 20,
                        aspectRatio: nil,
                        fixedHeight: nil
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                @unknown default:
                    AttachmentBlurHashPlaceholderView(
                        blurHash: attachment.blurhash,
                        cornerRadius: 20,
                        aspectRatio: nil,
                        fixedHeight: nil
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        } else {
            AttachmentBlurHashPlaceholderView(
                blurHash: attachment.blurhash,
                cornerRadius: 20,
                aspectRatio: nil,
                fixedHeight: nil
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
