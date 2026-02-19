//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct TrendingTagRowView: View {
    let hashtag: Hashtag
    let statuses: [Status]?
    let isLoadingStatuses: Bool
    var onHashtagTap: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let onHashtagTap {
                    Button(action: onHashtagTap) {
                        Text("#\(hashtag.name)")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.blue)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("#\(hashtag.name)")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.blue)
                        .lineLimit(1)
                }

                if let amount = hashtag.amount {
                    Text("\(amount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            TrendingHorizontalStatusesStripView(
                statuses: statuses,
                isLoading: isLoadingStatuses,
                emptyTitle: "No photos for this tag"
            )
        }
    }
}
