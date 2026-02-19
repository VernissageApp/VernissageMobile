//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct TimelineAuthorOverlayView: View {
    let user: User

    private var displayName: String {
        user.name?.nilIfEmpty ?? user.userName?.trimmingPrefix("@").nilIfEmpty ?? "Unknown"
    }

    var body: some View {
        HStack(spacing: 6) {
            AsyncAvatarView(urlString: user.avatarUrl, size: 20)

            Text(displayName)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(Color.black.opacity(0.56), in: Capsule(style: .continuous))
    }
}
