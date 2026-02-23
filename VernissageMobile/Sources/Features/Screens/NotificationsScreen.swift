//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct NotificationsScreen: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = NotificationsViewModel()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if viewModel.isLoading && viewModel.notifications.isEmpty {
                    ProgressView()
                        .tint(.white)
                        .padding(.top, 20)
                } else if viewModel.errorMessage != nil, viewModel.notifications.isEmpty {
                    ContentUnavailableView("Cannot load notifications",
                                           systemImage: "exclamationmark.triangle",
                                           description: Text("Please try again in a moment."))
                        .foregroundStyle(.white.opacity(0.9))
                } else if viewModel.notifications.isEmpty {
                    ContentUnavailableView("No notifications",
                                           systemImage: "bell",
                                           description: Text("Your notifications will appear here."))
                        .foregroundStyle(.white.opacity(0.9))
                } else {
                    ForEach(Array(viewModel.notifications.enumerated()), id: \.offset) { index, notification in
                        NotificationRowView(notification: notification)
                            .onAppear {
                                Task {
                                    await viewModel.loadMoreIfNeeded(using: appState, currentIndex: index)
                                }
                            }
                    }

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .tint(.white)
                            .padding(.vertical, 12)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onFirstAppear {
            let didLoad = await viewModel.load(using: appState)
            guard didLoad else {
                return
            }

            await updateMarkerAndRefreshCounter()
        }
        .refreshable {
            let didLoad = await viewModel.load(using: appState)
            guard didLoad else {
                return
            }

            await updateMarkerAndRefreshCounter()
        }
        .errorAlertToast(Binding(
            get: { viewModel.errorMessage },
            set: { viewModel.errorMessage = $0 }
        ))
    }

    @MainActor
    private func updateMarkerAndRefreshCounter() async {
        if let notificationId = viewModel.notifications.first?.id?.nilIfEmpty {
            do {
                try await appState.updateNotificationMarker(notificationId: notificationId)
            } catch {
                // If marker update fails, keep notifications list visible and still refresh the counter.
            }
        }

        await appState.refreshUnreadNotificationsCount()
    }
}
