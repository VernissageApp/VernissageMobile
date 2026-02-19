//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct SharedBusinessCardSheet: View {
    @Environment(\.dismiss) private var dismiss

    let mode: SharedBusinessCardSheetMode
    let onSubmit: (SharedBusinessCardDraft) async -> Bool

    @State private var title: String
    @State private var note: String
    @State private var thirdPartyName: String
    @State private var thirdPartyEmail: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let titleLimit = 200
    private let noteLimit = 500

    init(
        mode: SharedBusinessCardSheetMode,
        onSubmit: @escaping (SharedBusinessCardDraft) async -> Bool
    ) {
        self.mode = mode
        self.onSubmit = onSubmit
        _title = State(initialValue: mode.initialTitle)
        _note = State(initialValue: mode.initialNote)
        _thirdPartyName = State(initialValue: mode.initialThirdPartyName)
        _thirdPartyEmail = State(initialValue: mode.initialThirdPartyEmail)
    }

    private var canSubmit: Bool {
        !isSaving && title.nilIfEmpty != nil
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                ZStack(alignment: .topLeading) {
                    TextField("", text: $title)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled(false)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.secondary.opacity(0.10))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.secondary.opacity(0.24), lineWidth: 1)
                        )
                        .onChange(of: title) { _, newValue in
                            if newValue.count > titleLimit {
                                title = String(newValue.prefix(titleLimit))
                            }
                        }

                    if title.isEmpty {
                        Text("Title*")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding(.top, 14)
                            .padding(.leading, 14)
                            .allowsHitTesting(false)
                    }
                }

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $note)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 120, maxHeight: 170)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.secondary.opacity(0.10))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.secondary.opacity(0.24), lineWidth: 1)
                        )
                        .onChange(of: note) { _, newValue in
                            if newValue.count > noteLimit {
                                note = String(newValue.prefix(noteLimit))
                            }
                        }

                    if note.isEmpty {
                        Text("Comment")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding(.top, 20)
                            .padding(.leading, 16)
                            .allowsHitTesting(false)
                        }
                }

                ZStack(alignment: .topLeading) {
                    TextField("", text: $thirdPartyName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(false)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.secondary.opacity(0.10))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.secondary.opacity(0.24), lineWidth: 1)
                        )

                    if thirdPartyName.isEmpty {
                        Text("User name")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding(.top, 14)
                            .padding(.leading, 14)
                            .allowsHitTesting(false)
                    }
                }

                ZStack(alignment: .topLeading) {
                    TextField("", text: $thirdPartyEmail)
                        .textInputAutocapitalization(.never)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled(true)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.secondary.opacity(0.10))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.secondary.opacity(0.24), lineWidth: 1)
                        )

                    if thirdPartyEmail.isEmpty {
                        Text("User email")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding(.top, 14)
                            .padding(.leading, 14)
                            .allowsHitTesting(false)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .navigationTitle(mode.title)
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
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text(mode.submitTitle)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!canSubmit)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .errorAlertToast($errorMessage)
    }

    @MainActor
    private func submit() async {
        guard canSubmit else {
            return
        }

        isSaving = true
        defer { isSaving = false }

        let draft = SharedBusinessCardDraft(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            thirdPartyName: thirdPartyName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            thirdPartyEmail: thirdPartyEmail.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )

        let success = await onSubmit(draft)
        if success {
            dismiss()
        } else {
            errorMessage = "Cannot save shared business card."
        }
    }
}
