//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct MessagesToolbarButtonView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if appState.supportsDirectMessages {
            NavigationLink {
                DirectMessagesScreen()
                    .id(appState.activeAccountID)
            } label: {
                Image(systemName: "bubble.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .accessibilityLabel(AppConstants.DirectMessages.title)
        } else {
            SettingsToolbarButtonView()
        }
    }
}
