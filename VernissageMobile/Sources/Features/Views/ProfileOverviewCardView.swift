//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ProfileOverviewCardView: View {
    let profile: User
    let latestFollowers: [User]
    let isAdministrator: Bool
    let showFollowButtons: Bool
    let relationship: Relationship?
    let onRelationshipChanged: ((Relationship) -> Void)?

    init(
        profile: User,
        latestFollowers: [User],
        isAdministrator: Bool,
        showFollowButtons: Bool = false,
        relationship: Relationship? = nil,
        onRelationshipChanged: ((Relationship) -> Void)? = nil
    ) {
        self.profile = profile
        self.latestFollowers = latestFollowers
        self.isAdministrator = isAdministrator
        self.showFollowButtons = showFollowButtons
        self.relationship = relationship
        self.onRelationshipChanged = onRelationshipChanged
    }

    private var isSupporterVisible: Bool {
        profile.isSupporter == true || profile.isSupporterFlagEnabled == true
    }

    private var displayName: String {
        profile.name?.nilIfEmpty ?? profile.userName ?? "Unknown"
    }

    private var displayUserName: String {
        "@\(profile.userName ?? "")"
    }

    private var joinedText: String? {
        guard profile.isLocal == true, let createdAt = profile.createdAt else {
            return nil
        }

        return "Joined \(createdAt.formatted(date: .long, time: .omitted))"
    }

    private var nonEmptyFields: [FlexiField] {
        (profile.fields ?? []).filter { field in
            field.key?.nilIfEmpty != nil || field.displayText?.nilIfEmpty != nil
        }
    }

    private var shownLatestFollowers: [User] {
        Array(latestFollowers.prefix(10))
    }

    private var flexiFieldsBackgroundColor: Color {
        Color(uiColor: .secondarySystemBackground)
    }

    private var flexiFieldsDividerColor: Color {
        Color(uiColor: .separator).opacity(0.35)
    }

    private var flexiFieldsBorderColor: Color {
        Color(uiColor: .separator).opacity(0.22)
    }

    var body: some View {
        VStack(spacing: 16) {
            if let headerURL = profile.headerUrl?.nilIfEmpty {
                ZStack(alignment: .bottom) {
                    ProfileHeaderImageView(urlString: headerURL)
                        .frame(maxWidth: .infinity)
                        .frame(height: 188)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    AsyncAvatarView(urlString: profile.avatarUrl, size: 140)
                        .overlay(Circle().stroke(.white.opacity(0.92), lineWidth: 4))
                        .offset(y: 68)
                }
                .padding(.bottom, 68)
            } else {
                AsyncAvatarView(urlString: profile.avatarUrl, size: 140)
                    .overlay(Circle().stroke(.white.opacity(0.92), lineWidth: 4))
            }
            
            VStack(spacing: 0) {
                Text(displayName)
                    .font(.title.weight(.bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                
                Text(displayUserName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }

            if showFollowButtons {
                FollowButtonsSectionView(
                    user: profile,
                    relationship: relationship,
                    singleButton: false,
                    onRelationshipChanged: onRelationshipChanged
                )
                .frame(maxWidth: .infinity, alignment: .center)
            }

            if isAdministrator || isSupporterVisible {
                HStack(spacing: 10) {
                    if isAdministrator {
                        ProfileFlagChipView(title: "Administrator",
                                        systemImage: "person.badge.key.fill",
                                        style: .administrator)
                    }

                    if isSupporterVisible {
                        ProfileFlagChipView(title: "Supporter",
                                        systemImage: "sparkles",
                                        style: .supporter)
                    }
                }
                .padding(.horizontal, 12)
            }

            if let bioMarkdown = profile.displayBioMarkdown?.nilIfEmpty {
                MarkdownFormattedTextView(bioMarkdown)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
            } else if let bioText = profile.displayBio?.nilIfEmpty {
                Text(bioText)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
            }

            if let joinedText {
                Text(joinedText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 18) {
                ProfileMetricView(title: "Photos", value: profile.photosCount ?? profile.statusesCount ?? 0)
                ProfileMetricView(title: "Followers", value: profile.followersCount ?? 0)
                ProfileMetricView(title: "Following", value: profile.followingCount ?? 0)
            }
            .padding(.top, 4)
            .padding(.horizontal, 8)

            if !shownLatestFollowers.isEmpty {
                VStack(spacing: 8) {
                    Text("LATEST FOLLOWERS")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 0) {
                        ForEach(Array(shownLatestFollowers.enumerated()), id: \.offset) { index, follower in
                            AsyncAvatarView(urlString: follower.avatarUrl, size: 40)
                                .overlay(
                                    Circle()
                                        .stroke(Color(uiColor: .systemBackground), lineWidth: 2)
                                )
                                .padding(.leading, index == 0 ? 0 : -12)
                                .zIndex(Double(shownLatestFollowers.count - index))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 2)
                }
                .padding(.top, 2)
            }

            if !nonEmptyFields.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(nonEmptyFields.enumerated()), id: \.offset) { index, item in
                        ProfileFieldRowView(field: item)

                        if index < nonEmptyFields.count - 1 {
                            Divider()
                                .overlay(flexiFieldsDividerColor)
                        }
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(flexiFieldsBackgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(flexiFieldsBorderColor, lineWidth: 1)
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
