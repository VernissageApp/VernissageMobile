//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct HashtagSearchRowView: View {
    let hashtag: Hashtag

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "number")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text("#\(hashtag.name)")
                    .font(.headline)
                    .foregroundStyle(.blue)

                if let amount = hashtag.amount {
                    Text("\(amount) posts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
    }
}
