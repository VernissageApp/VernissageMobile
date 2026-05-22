//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct NotificationGroupRowView: View {
    let group: NotificationGroup

    private var visibleNotifications: ArraySlice<AppNotification> {
        group.notifications.prefix(7)
    }

    private var hiddenNotificationsCount: Int {
        max(0, group.notifications.count - visibleNotifications.count)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            notificationTypeBadge
                .frame(width: 32, height: 52)

            VStack(alignment: .leading, spacing: 7) {
                avatarsView

                Text(group.displayText)
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if let latestCreatedAtLabel = group.latestCreatedAtLabel {
                    Text(latestCreatedAtLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let linkedStatus = group.linkedStatus {
                NotificationStatusThumbnailView(status: linkedStatus)
                    .padding(.leading, 8)
            }
        }
        .padding(12)
        .liquidGlassCard()
    }

    private var avatarsView: some View {
        HStack(spacing: -6) {
            ForEach(Array(visibleNotifications), id: \.uniquenessKey) { notification in
                if let actorUserName = normalizedUserName(for: notification) {
                    NavigationLink {
                        UserProfileScreen(userName: actorUserName, preferredDisplayName: displayName(for: notification))
                    } label: {
                        AsyncAvatarView(urlString: notification.byUser?.avatarUrl, size: 30)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(displayName(for: notification))
                } else {
                    AsyncAvatarView(urlString: notification.byUser?.avatarUrl, size: 30)
                }
            }

            if hiddenNotificationsCount > 0 {
                Text("+\(hiddenNotificationsCount)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 10)
                    .accessibilityLabel("\(hiddenNotificationsCount) more people")
            }
        }
    }

    private var notificationTypeBadge: some View {
        Image(systemName: group.iconName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(group.representative.iconColor)
            )
            .overlay(
                Circle()
                    .stroke(Color(uiColor: .systemBackground), lineWidth: 2)
            )
            .accessibilityHidden(true)
    }

    private func displayName(for notification: AppNotification) -> String {
        notification.byUser?.name?.nilIfEmpty ?? notification.byUser?.userName ?? "Unknown"
    }

    private func normalizedUserName(for notification: AppNotification) -> String? {
        notification.byUser?.userName?.trimmingPrefix("@").nilIfEmpty
    }
}
