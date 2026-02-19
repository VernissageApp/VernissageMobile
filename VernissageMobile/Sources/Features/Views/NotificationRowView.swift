//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct NotificationRowView: View {
    let notification: AppNotification

    private var actorDisplayName: String {
        notification.byUser?.name?.nilIfEmpty ?? notification.byUser?.userName ?? "Unknown"
    }

    private var actorUserName: String? {
        notification.byUser?.userName?.trimmingPrefix("@").nilIfEmpty
    }

    private var linkedStatus: Status? {
        if let mainStatus = notification.mainStatus, mainStatus.hasAttachment {
            return mainStatus
        }

        if let status = notification.status, status.hasAttachment {
            return status
        }

        if let mainStatus = notification.mainStatus {
            return mainStatus
        }

        return notification.status
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .leading) {
                if let actorUserName {
                    NavigationLink {
                        UserProfileScreen(userName: actorUserName, preferredDisplayName: actorDisplayName)
                    } label: {
                        AsyncAvatarView(urlString: notification.byUser?.avatarUrl, size: 52)
                            .padding(.leading, 12)
                    }
                    .buttonStyle(.plain)
                } else {
                    AsyncAvatarView(urlString: notification.byUser?.avatarUrl, size: 52)
                        .padding(.leading, 12)
                }

                Image(systemName: notification.iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(notification.iconColor)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color(uiColor: .systemBackground), lineWidth: 2)
                    )
                    .offset(x: -2)
                    .zIndex(1)
            }
            .frame(width: 64, height: 52, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(actorDisplayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
                    .lineLimit(1)

                if let actorUserName = notification.byUser?.userName?.nilIfEmpty {
                    Text("@\(actorUserName.trimmingPrefix("@"))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(notification.displayText)
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if let createdAt = notification.createdAt {
                    Text(createdAt.relativeDateLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let linkedStatus {
                NavigationLink {
                    StatusDetailScreen(status: linkedStatus)
                } label: {
                    if let imageURL = linkedStatus.firstAttachmentURL {
                        AsyncImage(url: URL(string: imageURL),
                                   transaction: Transaction(animation: .easeInOut(duration: 0.3))) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 74, height: 74)
                                    .transition(.opacity)
                            case .empty, .failure:
                                AttachmentBlurHashPlaceholderView(blurHash: linkedStatus.firstAttachmentBlurHash,
                                                              cornerRadius: 10,
                                                              aspectRatio: 1,
                                                              fixedHeight: 74)
                            @unknown default:
                                AttachmentBlurHashPlaceholderView(blurHash: linkedStatus.firstAttachmentBlurHash,
                                                              cornerRadius: 10,
                                                              aspectRatio: 1,
                                                              fixedHeight: 74)
                            }
                        }
                        .frame(width: 74, height: 74)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.white.opacity(0.08))
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.system(size: 20, weight: .regular))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 74, height: 74)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(.white.opacity(0.14), lineWidth: 1)
                            )
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .liquidGlassCard()
    }
}
