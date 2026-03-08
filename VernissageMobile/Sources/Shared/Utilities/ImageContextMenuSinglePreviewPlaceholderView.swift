//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ImageContextMenuSinglePreviewPlaceholderView: View {
    private let previewImageSize: CGFloat = 78

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 12)
                .fill(.secondary)
                .frame(width: previewImageSize, height: previewImageSize)

            VStack(alignment: .leading, spacing: 8) {
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
                        .font(.callout)
                    Text("Second placeholder line for preview content.")
                        .font(.callout)
                    Text("Third placeholder line.")
                        .font(.callout)
                }
            }
        }
    }
}
