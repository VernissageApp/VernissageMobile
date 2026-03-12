//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct DeleteAccountSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let requiredEmail: String?
    let onDeleted: () -> Void

    @State private var enteredEmail = ""
    @State private var isDeleting = false
    @State private var errorMessage: String?

    private var normalizedRequiredEmail: String? {
        requiredEmail?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().nilIfEmpty
    }

    private var normalizedEnteredEmail: String? {
        enteredEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().nilIfEmpty
    }

    private var canDelete: Bool {
        guard !isDeleting,
              let expected = normalizedRequiredEmail,
              let entered = normalizedEnteredEmail else {
            return false
        }

        return expected == entered
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("The operation will delete your account and all related data.")
                    .font(.headline)
                    .foregroundStyle(.red)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Email*")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("Email", text: $enteredEmail)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .padding(.horizontal, 12)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(uiColor: .secondarySystemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color(uiColor: .separator).opacity(0.55), lineWidth: 1)
                        )
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Before proceeding, please read these notes carefully:")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)

                    DeleteAccountNoteRowView(text: "You will not be able to restore or reactivate your account")
                    DeleteAccountNoteRowView(text: "Your username will remain unavailable")
                    DeleteAccountNoteRowView(text: "Your posts and other data will be permanently removed")
                    DeleteAccountNoteRowView(text: "Content that has been cached by other servers may persist")
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle("Delete account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isDeleting)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        Task { await deleteAccount() }
                    } label: {
                        if isDeleting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Delete")
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.red)
                    .disabled(!canDelete)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .errorAlertToast($errorMessage)
    }

    @MainActor
    private func deleteAccount() async {
        guard canDelete else {
            return
        }

        isDeleting = true
        defer { isDeleting = false }

        do {
            try await appState.api.users.deleteActiveAccount()
            onDeleted()
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
