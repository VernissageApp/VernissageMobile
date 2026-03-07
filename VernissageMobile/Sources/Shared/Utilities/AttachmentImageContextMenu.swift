//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct AttachmentImageContextMenu: ViewModifier {
    private let attachment: Attachment

    @State private var actionErrorMessage: String?
    @State private var actionSuccessMessage: String?

    init(attachment: Attachment) {
        self.attachment = attachment
    }

    func body(content: Content) -> some View {
        content
            .contextMenu {
                if let imageURL = imageURL {
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
                .disabled(imageURL == nil)
            }
            .errorAlertToast($actionErrorMessage)
            .successAlertToast($actionSuccessMessage)
    }

    private var imageURL: URL? {
        let imageURLString = attachment.orginalImageURL?.nilIfEmpty ?? attachment.smallImageURL?.nilIfEmpty
        guard let imageURLString, let url = URL(string: imageURLString) else {
            return nil
        }

        return url
    }

    @MainActor
    private func saveImage() async {
        guard let imageURL else {
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
}

extension View {
    func attachmentImageContextMenu(attachment: Attachment) -> some View {
        modifier(AttachmentImageContextMenu(attachment: attachment))
    }
}
