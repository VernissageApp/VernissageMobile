//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct UserBlockSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let user: User
    let onRelationshipChanged: ((Relationship) -> Void)?

    @State private var reason = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    init(user: User, onRelationshipChanged: ((Relationship) -> Void)? = nil) {
        self.user = user
        self.onRelationshipChanged = onRelationshipChanged
    }

    private var normalizedUserName: String? {
        user.userName?.trimmingPrefix("@").nilIfEmpty
    }

    private var canSubmit: Bool {
        !isSubmitting && normalizedUserName != nil
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("This user can no longer follow you unless they already do. Their posts will not appear in your local timeline, and your posts will not be delivered directly to them. However, they may still see your posts if someone they follow boosts them.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                TextField("Reason", text: $reason, axis: .vertical)
                    .lineLimit(2, reservesSpace: true)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.secondary.opacity(0.10))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.secondary.opacity(0.24), lineWidth: 1)
                    )

                Spacer(minLength: 0)
            }
            .padding(16)
            .navigationTitle("Block user")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await submitAction() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Block")
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
    private func submitAction() async {
        guard let userName = normalizedUserName else {
            errorMessage = "Cannot change user block state."
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let updatedRelationship = try await appState.api.users.blockUser(userName: userName, reason: reason.nilIfEmpty)
            appState.showSuccessToast("User has been blocked.")
            onRelationshipChanged?(updatedRelationship)
            errorMessage = nil
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
