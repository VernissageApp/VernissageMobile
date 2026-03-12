//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct StatusReportSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private let status: Status?
    private let explicitReportedUserId: String?

    @State private var comment = ""
    @State private var selectedCategory: String?
    @State private var selectedRuleIds: Set<Int> = []
    @State private var availableRules: [InstanceRule] = []
    @State private var isRulesLoading = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @FocusState private var isCommentFocused: Bool

    private let maxCommentLength = 1000
    private static let categories = [
        "Abusive",
        "Copyright",
        "Impersonation",
        "Scam",
        "Sensitive",
        "Spam",
        "Terrorism",
        "Underage",
        "Violence"
    ]

    init(status: Status) {
        self.status = status
        self.explicitReportedUserId = nil
    }

    init(reportedUserId: String) {
        self.status = nil
        self.explicitReportedUserId = reportedUserId
    }

    private var reportedUserId: String? {
        explicitReportedUserId?.nilIfEmpty ?? status?.user?.id?.nilIfEmpty
    }

    private var selectedRulesLabel: String {
        if isRulesLoading && availableRules.isEmpty {
            return "Loading..."
        }

        let selectedRules = availableRules.filter { selectedRuleIds.contains($0.id) }
        if selectedRules.isEmpty {
            return "Select rules"
        }

        if selectedRules.count == 1 {
            return selectedRules[0].text
        }

        return "\(selectedRules.count) selected"
    }

    private var canSubmit: Bool {
        !isSubmitting && reportedUserId != nil
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $comment)
                        .focused($isCommentFocused)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 130, maxHeight: 210)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.secondary.opacity(0.10))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.secondary.opacity(0.24), lineWidth: 1)
                        )
                        .onChange(of: comment) { _, newValue in
                            if newValue.count > maxCommentLength {
                                comment = String(newValue.prefix(maxCommentLength))
                            }
                        }

                    if comment.isEmpty {
                        Text("Comment")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding(.top, 20)
                            .padding(.leading, 16)
                            .allowsHitTesting(false)
                    }
                }

                HStack {
                    Spacer(minLength: 0)
                    Text("\(comment.count)/\(maxCommentLength)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                menuField(title: "Category", value: selectedCategory ?? "Select category") {
                    Button {
                        selectedCategory = nil
                    } label: {
                        if selectedCategory == nil {
                            Label("Select category", systemImage: "checkmark")
                        } else {
                            Text("Select category")
                        }
                    }

                    Divider()

                    ForEach(Self.categories, id: \.self) { category in
                        Button {
                            selectedCategory = category
                        } label: {
                            if selectedCategory == category {
                                Label(category, systemImage: "checkmark")
                            } else {
                                Text(category)
                            }
                        }
                    }
                }

                menuField(title: "Server rules", value: selectedRulesLabel) {
                    if isRulesLoading && availableRules.isEmpty {
                        Text("Loading...")
                    } else if availableRules.isEmpty {
                        Text("No server rules")
                    } else {
                        ForEach(availableRules) { rule in
                            Button {
                                toggleRule(rule.id)
                            } label: {
                                if selectedRuleIds.contains(rule.id) {
                                    Label(rule.text, systemImage: "checkmark")
                                } else {
                                    Text(rule.text)
                                }
                            }
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await submitReport() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Report")
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSubmit)
                }
            }
            .onFirstAppear {
                await loadRulesIfNeeded()
            }
            .task {
                try? await Task.sleep(for: .milliseconds(150))
                isCommentFocused = true
            }
        }
        .errorAlertToast($errorMessage)
    }

    @ViewBuilder
    private func menuField<MenuContent: View>(
        title: String,
        value: String,
        @ViewBuilder menuContent: () -> MenuContent
    ) -> some View {
        Menu {
            menuContent()
        } label: {
            HStack(spacing: 10) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer(minLength: 10)

                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.secondary.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.secondary.opacity(0.24), lineWidth: 1)
            )
        }
    }

    @MainActor
    private func loadRulesIfNeeded() async {
        guard availableRules.isEmpty, !isRulesLoading else {
            return
        }

        isRulesLoading = true
        defer { isRulesLoading = false }

        do {
            availableRules = try await appState.api.instance.fetchInstanceRules()
            errorMessage = nil
        } catch {
            availableRules = []
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func toggleRule(_ ruleId: Int) {
        if selectedRuleIds.contains(ruleId) {
            selectedRuleIds.remove(ruleId)
        } else {
            selectedRuleIds.insert(ruleId)
        }
    }

    @MainActor
    private func submitReport() async {
        guard let reportedUserId = reportedUserId else {
            errorMessage = "Cannot report this user."
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await appState.api.reports.createReport(
                reportedUserId: reportedUserId,
                statusId: status?.id,
                comment: comment.trimmingCharacters(in: .whitespacesAndNewlines),
                category: selectedCategory,
                ruleIds: selectedRuleIds.sorted(),
                forward: false
            )

            errorMessage = nil
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
