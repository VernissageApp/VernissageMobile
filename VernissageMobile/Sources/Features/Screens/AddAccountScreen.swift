//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct AddAccountScreen: View {
    @EnvironmentObject private var appState: AppState

    let mode: AddAccountMode
    var onDone: (() -> Void)? = nil

    @State private var instanceURL = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var curatedInstances: [CuratedInstance] = []
    @State private var isCuratedInstancesLoading = false
    @State private var didLoadCuratedInstances = false
    @State private var curatedInstancesErrorMessage: String?
    @FocusState private var isInstanceURLFocused: Bool

    private var isAdditionalAccount: Bool {
        mode == .additionalAccount
    }

    private var screenBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.black,
                Color(red: 0.08, green: 0.06, blue: 0.18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var secondaryTextColor: Color {
        .white.opacity(0.82)
    }

    private var fieldLabelColor: Color {
        .white.opacity(0.75)
    }

    private var fieldFillColor: Color {
        .white.opacity(0.10)
    }

    private var fieldStrokeColor: Color {
        .white.opacity(0.22)
    }

    private var fieldTextColor: Color {
        .white
    }

    var body: some View {
        VStack(spacing: 16) {
            titleSection
            addAccountFormSection

            ScrollView {
                VStack(spacing: 16) {
                    curatedInstancesSection

                    if mode == .firstAccount {
                        Text("OAuth redirect scheme: vernissage-mobile://oauth-callback")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.60))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, isAdditionalAccount ? 16 : 0)
        .padding(.top, isAdditionalAccount ? 20 : 0)
        .background(
            screenBackgroundGradient
                .ignoresSafeArea()
        )
        .preferredColorScheme(.dark)
        .errorAlertToast($errorMessage)
        .task {
            await loadCuratedInstancesIfNeeded()
        }
    }

    @ViewBuilder
    private var titleSection: some View {
        if mode == .firstAccount {
            VStack(spacing: 8) {
                Text("Vernissage for iPhone")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                Text("Sign in with OAuth and access private timeline, local timeline, editors choice and profile.")
                    .font(.subheadline)
                    .foregroundStyle(secondaryTextColor)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var addAccountFormSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Instance URL")
                .font(.caption.weight(.semibold))
                .foregroundStyle(fieldLabelColor)

            TextField("https://your-vernissage.instance", text: $instanceURL)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .focused($isInstanceURLFocused)
                .onSubmit {
                    onAddAccountTap()
                }
                .padding(12)
                .background(fieldFillColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(fieldStrokeColor, lineWidth: 1)
                        .allowsHitTesting(false)
                )
                .foregroundStyle(fieldTextColor)

            Button(action: onAddAccountTap) {
                HStack(spacing: 8) {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    }
                    Text(mode == .firstAccount ? "Sign in with OAuth" : "Add account")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.blue)
                )
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .opacity(isSubmitting ? 0.72 : 1)
            .disabled(isSubmitting)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(fieldStrokeColor, lineWidth: 1)
                .allowsHitTesting(false)
        )
    }

    @ViewBuilder
    private var curatedInstancesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Suggested servers")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                if isCuratedInstancesLoading {
                    ProgressView()
                        .tint(.white)
                }
            }

            if let curatedInstancesErrorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text(curatedInstancesErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red.opacity(0.90))

                    Button("Retry") {
                        Task {
                            await loadCuratedInstancesIfNeeded(force: true)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
            }

            if isCuratedInstancesLoading && curatedInstances.isEmpty {
                ForEach(CuratedInstance.placeholders) { placeholder in
                    CuratedInstanceCardView(instance: placeholder) { }
                        .redacted(reason: .placeholder)
                        .allowsHitTesting(false)
                }
            } else {
                ForEach(curatedInstances) { instance in
                    CuratedInstanceCardView(instance: instance) {
                        instanceURL = instance.url.trimmingCharacters(in: .whitespacesAndNewlines)
                        isInstanceURLFocused = false
                    }
                }
            }
        }
    }

    private func onAddAccountTap() {
        guard !isSubmitting else {
            return
        }

        isInstanceURLFocused = false
        Task {
            await signIn()
        }
    }

    @MainActor
    private func loadCuratedInstancesIfNeeded(force: Bool = false) async {
        if isCuratedInstancesLoading {
            return
        }

        if didLoadCuratedInstances && !force {
            return
        }

        isCuratedInstancesLoading = true
        curatedInstancesErrorMessage = nil

        defer {
            isCuratedInstancesLoading = false
            didLoadCuratedInstances = true
        }

        do {
            curatedInstances = try await CuratedInstancesAPI.fetchInstances()
        } catch is CancellationError {
            return
        } catch {
            curatedInstances = []
            curatedInstancesErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    @MainActor
    private func signIn() async {
        let trimmed = instanceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Instance URL is required."
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await appState.signIn(instanceURLString: trimmed)
            errorMessage = nil
            onDone?()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
