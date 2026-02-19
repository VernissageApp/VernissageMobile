//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct TimelinePhotoTileView: View {
    let status: Status
    var showsAuthorOverlay: Bool = false
    var showsContentWarningOverlay: Bool = false
    var showsImageCountOverlay: Bool = false
    @AppStorage("settings.alwaysShowNsfw") private var alwaysShowNsfw = false
    @AppStorage("settings.showAvatarsOnTimeline") private var showAvatarsOnTimeline = false
    @AppStorage("settings.showImageCountsOnTimeline") private var showImageCountsOnTimeline = false

    private var mainStatus: Status {
        status.mainStatus
    }

    private var shouldHidePreviewImage: Bool {
        mainStatus.shouldHidePreviewImageOnTimelines(alwaysShowNsfw: alwaysShowNsfw)
    }

    private var shouldShowAuthorOverlay: Bool {
        showsAuthorOverlay && showAvatarsOnTimeline && mainStatus.user != nil
    }

    private var hiddenPreviewContentWarningText: String? {
        mainStatus.contentWarning?.nilIfEmpty
    }

    private var shouldShowImageCountOverlay: Bool {
        showsImageCountOverlay && showImageCountsOnTimeline && mainStatus.imageAttachmentsCount > 1
    }

    private var resolvedAttachmentAspectRatio: CGFloat {
        let ratio = mainStatus.firstAttachmentAspectRatio ?? 1
        return min(max(ratio, 0.2), 5.0)
    }

    var body: some View {
        GeometryReader { geometry in
            let tileWidth = max(geometry.size.width, 1)
            let tileHeight = max(geometry.size.height, 1)

            tileContent(width: tileWidth, height: tileHeight)
        }
        .aspectRatio(resolvedAttachmentAspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topLeading) {
            if shouldShowAuthorOverlay, let user = mainStatus.user {
                TimelineAuthorOverlayView(user: user)
                    .padding(.top, 10)
                    .padding(.leading, 10)
            }
        }
        .overlay(alignment: .topTrailing) {
            if shouldShowImageCountOverlay {
                TimelineImageCountOverlayView(current: 1, total: mainStatus.imageAttachmentsCount)
                    .padding(.top, 10)
                    .padding(.trailing, 10)
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func tileContent(width: CGFloat, height: CGFloat) -> some View {
        if shouldHidePreviewImage {
            AttachmentBlurHashPlaceholderView(
                blurHash: mainStatus.firstAttachmentBlurHash,
                cornerRadius: 0,
                aspectRatio: nil,
                fixedHeight: nil
            )
            .frame(width: width, height: height)
            .clipped()
            .overlay {
                if showsContentWarningOverlay,
                   let warning = hiddenPreviewContentWarningText {
                    TimelineContentWarningOverlayView(text: warning)
                        .padding(16)
                }
            }
        } else if let preview = mainStatus.firstAttachmentURL {
            AsyncImage(url: URL(string: preview),
                       transaction: Transaction(animation: .easeInOut(duration: 0.3))) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: width, height: height)
                        .transition(.opacity)
                case .empty, .failure:
                    AttachmentBlurHashPlaceholderView(
                        blurHash: mainStatus.firstAttachmentBlurHash,
                        cornerRadius: 0,
                        aspectRatio: nil,
                        fixedHeight: nil
                    )
                    .frame(width: width, height: height)
                    .clipped()
                @unknown default:
                    AttachmentBlurHashPlaceholderView(
                        blurHash: mainStatus.firstAttachmentBlurHash,
                        cornerRadius: 0,
                        aspectRatio: nil,
                        fixedHeight: nil
                    )
                    .frame(width: width, height: height)
                    .clipped()
                }
            }
        }
    }
}
