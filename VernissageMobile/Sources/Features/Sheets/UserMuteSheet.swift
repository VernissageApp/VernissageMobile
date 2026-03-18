//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct UserMuteSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let user: User
    let onRelationshipChanged: ((Relationship) -> Void)?

    @State private var muteStatuses: Bool
    @State private var muteReblogs: Bool
    @State private var muteNotifications: Bool
    @State private var removeStatusesFromTimeline = false
    @State private var removeReblogsFromTimeline = false
    @State private var isMuteEndDateEnabled: Bool
    @State private var muteEndDate: Date
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    init(user: User, relationship: Relationship?, onRelationshipChanged: ((Relationship) -> Void)? = nil) {
        self.user = user
        self.onRelationshipChanged = onRelationshipChanged
        _muteStatuses = State(initialValue: relationship?.mutedStatuses == true)
        _muteReblogs = State(initialValue: relationship?.mutedReblogs == true)
        _muteNotifications = State(initialValue: relationship?.mutedNotifications == true)
        _isMuteEndDateEnabled = State(initialValue: false)
        _muteEndDate = State(initialValue: Date())
    }

    private var normalizedUserName: String? {
        user.userName?.trimmingPrefix("@").nilIfEmpty
    }

    private var hasAnyMuteScopeSelected: Bool {
        muteStatuses || muteReblogs || muteNotifications
    }

    private var canSubmit: Bool {
        !isSubmitting && normalizedUserName != nil
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Muting statuses and reblogs only applies to your private photo timeline. The user's posts will still appear in the local and global timelines, as those timelines are visible to all users of the system.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Toggle("Mute new statuses", isOn: $muteStatuses)
                Toggle("Remove user's statuses", isOn: $removeStatusesFromTimeline)
                    .disabled(!muteStatuses)
                    .padding(.leading, 10)
                Toggle("Mute reblogs", isOn: $muteReblogs)
                Toggle("Remove user's reblogs", isOn: $removeReblogsFromTimeline)
                    .disabled(!muteReblogs)
                    .padding(.leading, 10)
                Toggle("Mute notifications", isOn: $muteNotifications)

                Divider()

                Toggle("Set mute end date", isOn: $isMuteEndDateEnabled)
                    .disabled(!hasAnyMuteScopeSelected)

                if isMuteEndDateEnabled {
                    DatePicker("Mute end date", selection: $muteEndDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .onChange(of: hasAnyMuteScopeSelected) { _, hasAnyMuteScopeSelected in
                if hasAnyMuteScopeSelected == false {
                    isMuteEndDateEnabled = false
                }
            }
            .navigationTitle("Mute account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await saveMuteSettings() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Mute")
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(!canSubmit)
                }
            }
        }
        .errorAlertToast($errorMessage)
    }

    @MainActor
    private func saveMuteSettings() async {
        guard let userName = normalizedUserName else {
            errorMessage = "Cannot mute this user."
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let updatedRelationship: Relationship
            if hasAnyMuteScopeSelected {
                updatedRelationship = try await appState.api.users.mute(
                    userName: userName,
                    muteStatuses: muteStatuses,
                    muteReblogs: muteReblogs,
                    muteNotifications: muteNotifications,
                    removeStatusesFromTimeline: muteStatuses && removeStatusesFromTimeline,
                    removeReblogsFromTimeline: muteReblogs && removeReblogsFromTimeline,
                    muteEnd: isMuteEndDateEnabled ? muteEndDate : nil
                )
            } else {
                updatedRelationship = try await appState.api.users.unmute(userName: userName)
            }

            onRelationshipChanged?(updatedRelationship)
            errorMessage = nil
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
