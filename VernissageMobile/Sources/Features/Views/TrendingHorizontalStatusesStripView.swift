//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct TrendingHorizontalStatusesStripView: View {
    let statuses: [Status]?
    let isLoading: Bool
    let emptyTitle: String

    private let tileHeight: CGFloat = 285
    private let containerHeight: CGFloat = 289
    private let placeholderRatios: [CGFloat] = [1.28, 0.94, 1.12]

    var body: some View {
        Group {
            if isLoading || statuses == nil {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 6) {
                        ForEach(placeholderRatios.indices, id: \.self) { index in
                            let ratio = placeholderRatios[index]
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(.secondary.opacity(0.18))
                                .frame(width: min(max(tileHeight * ratio, 110), 440), height: tileHeight)
                                .redacted(reason: .placeholder)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.visible)
            } else if let statuses, statuses.isEmpty {
                Text(emptyTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if let statuses {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 6) {
                        ForEach(statuses, id: \.id) { status in
                            NavigationLink {
                                StatusDetailScreen(status: status)
                            } label: {
                                TrendingStripPhotoTileView(status: status, height: tileHeight)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.visible)
            }
        }
        .frame(maxWidth: .infinity, minHeight: containerHeight, maxHeight: containerHeight, alignment: .topLeading)
    }
}
