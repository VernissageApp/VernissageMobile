//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct PushNotificationSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var viewModel = PushNotificationSettingsViewModel()

    var body: some View {
        @Bindable var bindableViewModel = viewModel

        NavigationStack {
            List {
                Section {
                    Toggle("Push notifications", isOn: $bindableViewModel.settings.notificationsEnabled)
                        .disabled(viewModel.isSaving)
                        .onChange(of: viewModel.settings.notificationsEnabled) {
                            Task {
                                await viewModel.requestAuthorizationAfterEnabling()
                            }
                        }
                } footer: {
                    Text("Receive notifications on this device.")
                }

                Section("Notification types") {
                    Toggle("Mentions", isOn: $bindableViewModel.settings.mentionEnabled)
                    Toggle("New comments", isOn: $bindableViewModel.settings.newCommentEnabled)
                    Toggle("Boosts", isOn: $bindableViewModel.settings.reblogEnabled)
                    Toggle("New followers", isOn: $bindableViewModel.settings.followEnabled)
                    Toggle("Follow requests", isOn: $bindableViewModel.settings.followRequestEnabled)
                    Toggle("Likes", isOn: $bindableViewModel.settings.favouriteEnabled)
                    Toggle("Status updates", isOn: $bindableViewModel.settings.updateEnabled)

                    if isModerator {
                        Toggle("New reports", isOn: $bindableViewModel.settings.adminReportEnabled)
                    }

                    if isAdministrator {
                        Toggle("New users", isOn: $bindableViewModel.settings.adminSignUpEnabled)
                    }
                }
                .disabled(viewModel.isPreferenceDisabled)
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(viewModel.isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Task {
                            let didSave = await viewModel.save(using: appState)
                            guard didSave else {
                                return
                            }

                            dismiss()
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(viewModel.isSaving)
                }
            }
            .overlay {
                if viewModel.isSaving || viewModel.isLoading {
                    ProgressView()
                }
            }
            .task {
                await viewModel.load(using: appState)
            }
            .errorAlertToast($bindableViewModel.errorMessage)
        }
    }

    private var isAdministrator: Bool {
        appState.activeTokenRoles.contains("administrator")
    }

    private var isModerator: Bool {
        let roles = appState.activeTokenRoles
        return roles.contains("administrator") || roles.contains("moderator")
    }
}
