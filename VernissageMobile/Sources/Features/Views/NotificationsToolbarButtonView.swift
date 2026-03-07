//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct NotificationsToolbarButtonView: View {
    @Environment(AppState.self) private var appState

    private var badgeCount: Int? {
        let count = appState.unreadNotificationsCount
        guard count > 0 else {
            return nil
        }

        return count > 99 ? 99 : count
    }

    var body: some View {
        NavigationLink {
            NotificationsScreen()
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 32, height: 32)
            }
            .frame(width: 32, height: 32)
        }
        .frame(width: 44, height: 44)
        .buttonStyle(.plain)
        .accessibilityLabel("Notifications")
        .applyIfLet(badgeCount) { view, count in
            view.badge(count)
        }
    }
}
