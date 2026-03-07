//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ShareComposeRootView: View {
    @State private var appState = AppState()
    let session: ShareComposeSession

    let onClose: () -> Void

    var body: some View {
        @Bindable var bindableSession = session

        Group {
            if appState.activeAccount == nil {
                NavigationStack {
                    ContentUnavailableView(
                        "Sign in required",
                        systemImage: "person.crop.circle.badge.exclamationmark",
                        description: Text("Open Vernissage and sign in first to publish from share sheet.")
                    )
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Close") {
                                onClose()
                            }
                        }
                    }
                }
            } else {
                ZStack(alignment: .top) {
                    AddStatusPlaceholderSheet(
                        initialAttachmentURLs: session.attachmentURLs,
                        onDismissRequested: onClose
                    )

                    if session.isPreparingAttachments {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Preparing photos...")
                                .font(.footnote)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.top, 8)
                    }
                }
            }
        }
        .environment(appState)
        .task {
            await appState.refreshActiveTokenIfNeeded(force: false)
        }
        .errorAlertToast($bindableSession.preparationErrorMessage)
    }
}
