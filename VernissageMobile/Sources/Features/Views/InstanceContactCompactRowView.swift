//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct InstanceContactCompactRowView: View {
    let user: User

    private var displayName: String {
        user.name?.nilIfEmpty ?? user.userName ?? "Unknown"
    }

    private var normalizedUserName: String? {
        user.userName?.trimmingPrefix("@").nilIfEmpty
    }

    var body: some View {
        
            if let normalizedUserName {
                NavigationLink {
                    UserProfileScreen(userName: normalizedUserName, preferredDisplayName: displayName)
                } label: {
                    HStack(spacing: 8) {
                        AsyncAvatarView(urlString: user.avatarUrl, size: 28)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(displayName)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .foregroundStyle(.blue)

                            Text("@\(normalizedUserName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .buttonStyle(.plain)
            } else {
                AsyncAvatarView(urlString: user.avatarUrl, size: 28)
            }
    }
}
