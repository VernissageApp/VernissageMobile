//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct UserBlockDomainSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let initialDomain: String

    @State private var domain: String
    @State private var reason = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    init(initialDomain: String) {
        self.initialDomain = initialDomain
        _domain = State(initialValue: initialDomain.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var normalizedDomain: String? {
        domain.nilIfEmpty
    }

    private var canSubmit: Bool {
        !isSubmitting && normalizedDomain != nil
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Users from this domain cannot follow you. Their posts will not appear in your local timeline, and your posts are not delivered directly to them. However, they may still see your posts if a third party they follow boosts them.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                TextField("Domain", text: $domain)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
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
                    .disabled(true)

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
            .navigationTitle("Block domain")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await blockDomain() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Save")
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
    private func blockDomain() async {
        guard let domain = normalizedDomain else {
            errorMessage = "Cannot block domain."
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await appState.api.users.blockDomain(domain: domain, reason: reason.nilIfEmpty)
            errorMessage = nil
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
