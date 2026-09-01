//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ExploreItemRowView: View {
    let item: ExploreItem
    let selection: ExploreContentSelection
    let statuses: [Status]?
    let isLoadingStatuses: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(item.name)
                    .font(.title3)
                    .bold()
                    .lineLimit(2)

                if let amount = item.amount {
                    Text(amount, format: .number)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            TrendingHorizontalStatusesStripView(
                statuses: statuses,
                isLoading: isLoadingStatuses,
                emptyTitle: "No photos for this \(selection.singularTitle)"
            )
        }
    }
}
