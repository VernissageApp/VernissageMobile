//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI
import UIKit

struct ImageContextMenu: ViewModifier {
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL

    @State private var currentStatus: Status
    @State private var actionErrorMessage: String?
    @State private var actionSuccessMessage: String?

    init(status: Status) {
        _currentStatus = State(initialValue: status.mainStatus)
    }

    func body(content: Content) -> some View {
        content
            .contextMenu {
                Button {
                    Task { await toggleReblog() }
                } label: {
                    Label(currentStatus.reblogged == true ? "Unboost" : "Boost", systemImage: "arrow.2.squarepath")
                }

                Button {
                    Task { await toggleFavourite() }
                } label: {
                    Label(currentStatus.favourited == true ? "Unfavourite" : "Favourite", systemImage: currentStatus.favourited == true ? "star.fill" : "star")
                }

                Button {
                    Task { await toggleBookmark() }
                } label: {
                    Label(currentStatus.bookmarked == true ? "Unbookmark" : "Bookmark", systemImage: currentStatus.bookmarked == true ? "bookmark.fill" : "bookmark")
                }

                Divider()

                Button {
                    openInBrowser()
                } label: {
                    Label("Open in browser", systemImage: "safari")
                }
                .disabled(currentStatus.shareURL?.nilIfEmpty == nil)

                Button {
                    copyLinkToPost()
                } label: {
                    Label("Copy link to post", systemImage: "link")
                }
                .disabled(currentStatus.shareURL?.nilIfEmpty == nil)

                if let statusURL = statusShareURL {
                    ShareLink(item: statusURL) {
                        Label("Share status", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Button {} label: {
                        Label("Share status", systemImage: "square.and.arrow.up")
                    }
                    .disabled(true)
                }

                Divider()

                if let imageURL = imageShareURL {
                    ShareLink(item: imageURL) {
                        Label("Share image", systemImage: "photo")
                    }
                } else {
                    Button {} label: {
                        Label("Share image", systemImage: "photo")
                    }
                    .disabled(true)
                }

                Button {
                    Task { await saveImage() }
                } label: {
                    Label("Save image", systemImage: "square.and.arrow.down")
                }
                .disabled(imageShareURL == nil)
            } preview: {
                ImageContextMenuPreview(status: currentStatus)
            }
            .errorAlertToast($actionErrorMessage)
            .successAlertToast($actionSuccessMessage)
    }

    private var statusShareURL: URL? {
        guard let shareURLString = currentStatus.shareURL?.nilIfEmpty,
              let url = URL(string: shareURLString) else {
            return nil
        }

        return url
    }

    private var imageShareURL: URL? {
        let imageURLString = currentStatus.primaryAttachment?.orginalImageURL?.nilIfEmpty
            ?? currentStatus.primaryAttachment?.smallImageURL?.nilIfEmpty

        guard let imageURLString, let url = URL(string: imageURLString) else {
            return nil
        }

        return url
    }

    private func copyLinkToPost() {
        guard let link = currentStatus.shareURL?.nilIfEmpty else {
            return
        }

        UIPasteboard.general.string = link
    }

    private func openInBrowser() {
        guard let url = statusShareURL else {
            return
        }

        openURL(url)
    }

    @MainActor
    private func saveImage() async {
        guard let imageURL = imageShareURL else {
            return
        }

        do {
            try await RemoteImageLibrarySaver.saveImage(from: imageURL)
            actionSuccessMessage = "The image has been saved to your photo library."
            actionErrorMessage = nil
        } catch {
            actionErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    @MainActor
    private func toggleReblog() async {
        let action: StatusInteractionAction = currentStatus.reblogged == true ? .unreblog : .reblog
        await performAction(action)
    }

    @MainActor
    private func toggleFavourite() async {
        let action: StatusInteractionAction = currentStatus.favourited == true ? .unfavourite : .favourite
        await performAction(action)
    }

    @MainActor
    private func toggleBookmark() async {
        let action: StatusInteractionAction = currentStatus.bookmarked == true ? .unbookmark : .bookmark
        await performAction(action)
    }

    @MainActor
    private func performAction(_ action: StatusInteractionAction) async {
        do {
            currentStatus = try await appState.api.statuses.updateStatusInteraction(statusId: currentStatus.id, action: action)
            actionErrorMessage = nil
        } catch {
            actionErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

extension View {
    func imageContextMenu(status: Status) -> some View {
        modifier(ImageContextMenu(status: status))
    }
}
