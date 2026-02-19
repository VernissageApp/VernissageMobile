//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct StatusBoostedByView: View {
    let user: User

    private var displayName: String {
        user.name?.nilIfEmpty ?? user.userName?.trimmingPrefix("@").nilIfEmpty ?? "Unknown"
    }

    private var userName: String? {
        user.userName?.trimmingPrefix("@").nilIfEmpty
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.2.squarepath")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            AsyncAvatarView(urlString: user.avatarUrl, size: 26)

            Text(displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            if let userName {
                Text("@\(userName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Boosted by \(displayName)")
    }
}
