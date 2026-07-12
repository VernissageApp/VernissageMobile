//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct NotificationsToolbarButtonView: View {
    @Environment(AppState.self) private var appState

    private var hasUnreadNotifications: Bool {
        appState.unreadNotificationsCount > 0
    }

    var body: some View {
        NavigationLink {
            NotificationsScreen()
        } label: {
            Image(systemName: hasUnreadNotifications ? "bell.badge" : "bell")
                .font(.system(size: 15, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(hasUnreadNotifications ? .red : .primary, .primary)
                .frame(width: 32, height: 32)
        }
        .frame(width: 44, height: 44)
        .buttonStyle(.plain)
        .accessibilityLabel("Notifications")
        .accessibilityValue(hasUnreadNotifications ? "Unread notifications" : "No unread notifications")
    }
}
