//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ProfileUserRowView: View {
    let user: User
    let relationship: Relationship?
    let showFollowButtons: Bool
    let singleButton: Bool
    let onRelationshipChanged: ((Relationship) -> Void)?

    init(
        user: User,
        relationship: Relationship? = nil,
        showFollowButtons: Bool = false,
        singleButton: Bool = false,
        onRelationshipChanged: ((Relationship) -> Void)? = nil
    ) {
        self.user = user
        self.relationship = relationship
        self.showFollowButtons = showFollowButtons
        self.singleButton = singleButton
        self.onRelationshipChanged = onRelationshipChanged
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            rowNavigationContent

            if showFollowButtons {
                FollowButtonsSectionView(
                    user: user,
                    relationship: relationship,
                    singleButton: singleButton,
                    isCompact: true,
                    onRelationshipChanged: onRelationshipChanged
                )
            }
        }
    }

    @ViewBuilder
    private var rowNavigationContent: some View {
        if let normalizedUserName = user.userName?.trimmingPrefix("@").nilIfEmpty {
            NavigationLink {
                UserProfileScreen(userName: normalizedUserName, preferredDisplayName: user.name?.nilIfEmpty)
            } label: {
                rowContent
            }
            .buttonStyle(.plain)
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncAvatarView(urlString: user.avatarUrl, size: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(user.name?.nilIfEmpty ?? user.userName ?? "Unknown")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                    .lineLimit(1)

                Text("@\(user.userName ?? "")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(spacing: 12) {
                    Text("\(user.photosCount ?? user.statusesCount ?? 0) Photos")
                    Text("\(user.followersCount ?? 0) Followers")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
