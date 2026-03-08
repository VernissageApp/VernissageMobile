//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ImageContextMenuMultiplePreviewPlaceholderView: View {
    let imageCount: Int

    private let previewImageSize: CGFloat = 78

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(0..<imageCount, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.secondary)
                        .frame(width: previewImageSize, height: previewImageSize)
                }
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(.secondary)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Display name")
                        .font(.caption.weight(.semibold))

                    Text("@username")
                        .font(.caption2)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Placeholder status line that will be replaced.")
                    .font(.body)
                Text("Second placeholder line for preview content.")
                    .font(.body)
                Text("Third placeholder line.")
                    .font(.body)
            }
        }
    }
}
