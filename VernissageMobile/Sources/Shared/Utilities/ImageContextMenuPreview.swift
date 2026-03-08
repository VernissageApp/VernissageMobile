//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ImageContextMenuPreview: View {
    let status: Status

    @State private var showsResolvedContent = false

    private let previewWidth: CGFloat = 360

    private var previewAttachments: [Attachment] {
        Array((status.mainStatus.attachments ?? []).prefix(4))
    }

    private var usesSingleImageLayout: Bool {
        previewAttachments.count == 1
    }

    var body: some View {
        Group {
            if showsResolvedContent {
                if usesSingleImageLayout, let attachment = previewAttachments.first {
                    ImageContextMenuSinglePreviewContentView(status: status, attachment: attachment)
                } else {
                    ImageContextMenuMultiplePreviewContentView(status: status, attachments: previewAttachments)
                }
            } else {
                if usesSingleImageLayout {
                    ImageContextMenuSinglePreviewPlaceholderView()
                } else {
                    ImageContextMenuMultiplePreviewPlaceholderView(imageCount: max(1, previewAttachments.count))
                }
            }
        }
        .redacted(reason: showsResolvedContent ? [] : .placeholder)
        .task {
            if showsResolvedContent == false {
                showsResolvedContent = true
            }
        }
        .padding(12)
        .frame(width: previewWidth, alignment: .leading)
        .frame(minHeight: 100, alignment: .topLeading)
    }
}
