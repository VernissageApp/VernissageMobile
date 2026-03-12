//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct StatusTextTemplateSheet: View {
    let template: String
    let onSave: (String) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draftTemplate: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(template: String, onSave: @escaping (String) async throws -> Void) {
        self.template = template
        self.onSave = onSave
        _draftTemplate = State(initialValue: template)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $draftTemplate)
                        .frame(minHeight: 150)
                        .onChange(of: draftTemplate, initial: false) { _, newValue in
                            if newValue.count > 1000 {
                                draftTemplate = String(newValue.prefix(1000))
                            }
                        }
                } header: {
                    Text("Template")
                } footer: {
                    Text("\(draftTemplate.count)/1000")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .navigationTitle("Status template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await saveTemplate()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Save")
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(isSaving)
                }
            }
        }
        .errorAlertToast($errorMessage)
    }

    @MainActor
    private func saveTemplate() async {
        guard !isSaving else {
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            try await onSave(draftTemplate)
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
