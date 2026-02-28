//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct RootScreen: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black.opacity(0.95), Color.blue.opacity(0.30), Color.black.opacity(0.98)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if appState.activeAccount == nil {
                AddAccountScreen(mode: .firstAccount)
                    .padding(20)
            } else {
                MainTabScreen()
            }
        }
        .warningAlertToast($appState.warningToastMessage)
        .errorAlertToast($appState.toastMessage)
        .errorAlertToast($appState.globalErrorMessage)
        .task(id: appState.activeAccountID) {
            await appState.refreshActiveTokenIfNeeded(force: false)
            await appState.refreshUnreadNotificationsCount()
            appState.scheduleInactiveAccountsTokenRefreshIfNeeded()
        }
        .onChange(of: scenePhase, initial: false) { _, newPhase in
            guard newPhase == .active else {
                return
            }

            Task {
                await appState.refreshUnreadNotificationsCount()
            }
        }
    }
}
