//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct UserUnfollowSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let user: User
    let onRelationshipChanged: ((Relationship) -> Void)?

    @State private var removeStatusesFromTimeline = false
    @State private var removeReblogsFromTimeline = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var normalizedUserName: String? {
        user.userName?.trimmingPrefix("@").nilIfEmpty
    }

    private var canSubmit: Bool {
        !isSubmitting && normalizedUserName != nil
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("This action will prevent the user's new posts and reblogs from appearing on your private photo timeline. However, they may still appear if another user you follow reblogs (boosts) that user's post. You can also choose what to do with the user's existing posts already visible on your timeline. Removing them is irreversible.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Toggle("Remove user's statuses from your timeline", isOn: $removeStatusesFromTimeline)
                Toggle("Remove user's reblogs from your timeline", isOn: $removeReblogsFromTimeline)

                Spacer(minLength: 0)
            }
            .padding(16)
            .navigationTitle("Unfollow account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await unfollow() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Unfollow")
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
    private func unfollow() async {
        guard let userName = normalizedUserName else {
            errorMessage = "Cannot unfollow this user."
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let updatedRelationship = try await appState.api.users.unfollow(
                userName: userName,
                removeStatusesFromTimeline: removeStatusesFromTimeline,
                removeReblogsFromTimeline: removeReblogsFromTimeline
            )

            onRelationshipChanged?(updatedRelationship)
            appState.showSuccessToast("You have unfollowed the user.")
            errorMessage = nil
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
