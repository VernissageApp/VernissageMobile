//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI
import NukeUI

struct TimelinePhotoTileView: View {
    let status: Status
    var showsAuthorOverlay: Bool = false
    var showsContentWarningOverlay: Bool = false
    var showsImageCountOverlay: Bool = false
    @AppStorage(AppConstants.StorageKeys.settingsAlwaysShowNsfw) private var alwaysShowNsfw = false
    @AppStorage(AppConstants.StorageKeys.settingsShowAvatarsOnTimeline) private var showAvatarsOnTimeline = false
    @AppStorage(AppConstants.StorageKeys.settingsShowImageCountsOnTimeline) private var showImageCountsOnTimeline = false
    @State private var imageOpacity: Double = 0
    @State private var animatedPreviewURL: String?

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
            LazyImage(url: URL(string: preview)) { state in
                let hasImage = state.image != nil

                ZStack {
                    timelinePlaceholder(width: width, height: height)
                        .opacity(hasImage ? (1 - imageOpacity) : 1)

                    if let image = state.image {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(width: width, height: height)
                            .opacity(imageOpacity)
                            .onAppear {
                                animateImageAppearance()
                            }
                    }
                }
                .clipped()
                .onChange(of: preview, initial: true) { _, newPreview in
                    prepareImageAppearance(for: newPreview)
                }
            }
        }
    }

    private func timelinePlaceholder(width: CGFloat, height: CGFloat) -> some View {
        AttachmentBlurHashPlaceholderView(
            blurHash: mainStatus.firstAttachmentBlurHash,
            cornerRadius: 0,
            aspectRatio: nil,
            fixedHeight: nil
        )
        .frame(width: width, height: height)
        .clipped()
    }

    private func prepareImageAppearance(for preview: String) {
        guard animatedPreviewURL != preview else {
            return
        }

        animatedPreviewURL = preview
        imageOpacity = 0
    }

    private func animateImageAppearance() {
        guard imageOpacity < 1 else {
            return
        }

        withAnimation(.easeInOut(duration: 0.28)) {
            imageOpacity = 1
        }
    }
}
