//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct StatusContentWarningSheet: View {
    @Environment(\.dismiss) private var dismiss

    let initialContentWarning: String
    let onSubmit: @MainActor (String) async throws -> Void

    @State private var contentWarning: String
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    init(initialContentWarning: String, onSubmit: @escaping @MainActor (String) async throws -> Void) {
        self.initialContentWarning = initialContentWarning
        self.onSubmit = onSubmit
        _contentWarning = State(initialValue: initialContentWarning)
    }

    private var trimmedContentWarning: String? {
        contentWarning.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    private var canSubmit: Bool {
        !isSubmitting && trimmedContentWarning != nil
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("Enter new content warning for the status.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("Content warning*", text: $contentWarning, axis: .vertical)
                    .lineLimit(1...3)
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
            .navigationTitle("Content warning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Send")
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSubmit)
                }
            }
        }
        .errorAlertToast($errorMessage)
    }

    @MainActor
    private func submit() async {
        guard let trimmedContentWarning else {
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await onSubmit(trimmedContentWarning)
            errorMessage = nil
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
