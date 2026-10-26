//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct DirectConversationRowView: View {
    let conversation: DirectConversation
    let currentUserID: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            let participants = conversation.otherParticipants(currentUserID: currentUserID)
            HStack(spacing: -16) {
                ForEach(participants.prefix(2), id: \.uniquenessKey) { user in
                    AsyncAvatarView(urlString: user.avatarUrl, size: 44)
                }
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(conversation.title(currentUserID: currentUserID))
                        .font(.headline)
                    Spacer(minLength: 4)
                    Text(conversation.lastActivityAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text(conversation.lastMessageDeletedAt != nil
                         ? AppConstants.DirectMessages.deletedMessage
                         : conversation.summary?.nilIfEmpty ?? "Photo")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Spacer(minLength: 4)

                    if conversation.isMuted {
                        Image(systemName: "bell.slash")
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Muted")
                    }

                    if conversation.hasUnreadMessages {
                        Image(systemName: "circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.tint)
                            .accessibilityLabel("Unread messages")
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}
