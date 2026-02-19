//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct TrendingArtistRowView: View {
    let user: User
    let statuses: [Status]?
    let isLoadingStatuses: Bool

    private var displayName: String {
        user.name?.nilIfEmpty ?? user.userName ?? "Unknown"
    }

    private var displayUserName: String? {
        user.userName?.trimmingPrefix("@").nilIfEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                if let userName = displayUserName {
                    NavigationLink {
                        UserProfileScreen(userName: userName, preferredDisplayName: displayName)
                    } label: {
                        AsyncAvatarView(urlString: user.avatarUrl, size: 46)
                    }
                    .buttonStyle(.plain)
                } else {
                    AsyncAvatarView(urlString: user.avatarUrl, size: 46)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.headline)
                        .foregroundStyle(.blue)
                        .lineLimit(1)

                    if let userName = displayUserName {
                        Text("@\(userName)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 10) {
                        Text("\(user.photosCount ?? user.statusesCount ?? 0) Photos")
                        Text("\(user.followersCount ?? 0) Followers")
                        Text("\(user.followingCount ?? 0) Following")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            TrendingHorizontalStatusesStripView(
                statuses: statuses,
                isLoading: isLoadingStatuses,
                emptyTitle: "No photos yet"
            )
        }
    }
}
