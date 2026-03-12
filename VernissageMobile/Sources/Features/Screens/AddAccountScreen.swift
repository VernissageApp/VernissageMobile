//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct AddAccountScreen: View {
    private struct RegistrationDestination: Identifiable {
        let id = UUID()
        let instanceURL: URL
        let instanceDetails: InstanceDetails
        let publicSettings: PublicSettings
    }

    @Environment(AppState.self) private var appState

    let mode: AddAccountMode
    var onDone: (() -> Void)? = nil

    @State private var instanceURL = ""
    @State private var isSigningIn = false
    @State private var isPreparingRegistration = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var curatedInstances: [CuratedInstance] = []
    @State private var isCuratedInstancesLoading = false
    @State private var didLoadCuratedInstances = false
    @State private var curatedInstancesErrorMessage: String?
    @State private var registrationDestination: RegistrationDestination?
    @State private var showsInstanceURLRequiredError = false
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

    private var fieldErrorStrokeColor: Color {
        .red.opacity(0.88)
    }

    private var fieldTextColor: Color {
        .white
    }

    private var instanceURLValidationMessage: String? {
        showsInstanceURLRequiredError ? AppConstants.Copy.instanceURLRequired : nil
    }

    private var instanceURLStrokeColor: Color {
        showsInstanceURLRequiredError ? fieldErrorStrokeColor : fieldStrokeColor
    }

    private var isActionInProgress: Bool {
        isSigningIn || isPreparingRegistration
    }

    private var filteredCuratedInstances: [CuratedInstance] {
        let query = normalizedFilterQuery
        guard !query.isEmpty else {
            return curatedInstances
        }

        return curatedInstances.filter { instance in
            normalizeInstanceURLForMatching(instance.url).contains(query)
        }
    }

    private var normalizedFilterQuery: String {
        normalizeInstanceURLForMatching(instanceURL)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Add account")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .padding(.top, 12)
                    .padding(.bottom, 6)

                addAccountFormSection
                    .zIndex(1)

                curatedInstancesSection
                    .zIndex(0)

                if mode == .firstAccount {
                    Text("OAuth redirect scheme: \(AppConstants.OAuth.redirectURI)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.60))
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.horizontal, 16)
            .padding(.top, isAdditionalAccount ? 20 : 0)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .scrollDismissesKeyboard(.immediately)
        .background(
            screenBackgroundGradient
                .ignoresSafeArea()
        )
        .preferredColorScheme(.dark)
        .errorAlertToast($errorMessage)
        .successAlertToast($successMessage)
        .fullScreenCover(item: $registrationDestination) { destination in
            RegisterAccountScreen(
                instanceURL: destination.instanceURL,
                instanceDetails: destination.instanceDetails,
                publicSettings: destination.publicSettings
            ) { message in
                successMessage = message
            }
        }
        .task {
            await loadCuratedInstancesIfNeeded()
        }
        .onChange(of: instanceURL) { _, newValue in
            guard showsInstanceURLRequiredError else {
                return
            }

            if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                showsInstanceURLRequiredError = false
            }
        }
    }

    private var addAccountFormSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Instance URL")
                .font(.caption.weight(.semibold))
                .foregroundStyle(fieldLabelColor)

            TextField("your-vernissage.instance", text: $instanceURL)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .focused($isInstanceURLFocused)
                .onSubmit {
                    onSignInTap()
                }
                .padding(.leading, 12)
                .padding(.vertical, 12)
                .padding(.trailing, instanceURL.isEmpty ? 12 : 40)
                .foregroundStyle(fieldTextColor)
                .overlay(alignment: .trailing) {
                    if !instanceURL.isEmpty {
                        Button {
                            instanceURL = ""
                            isInstanceURLFocused = true
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.65))
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 12)
                        .accessibilityLabel("Clear instance URL")
                    }
                }
                .background(fieldFillColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(instanceURLStrokeColor, lineWidth: 1)
                        .allowsHitTesting(false)
                )
                .foregroundStyle(fieldTextColor)

            if let instanceURLValidationMessage {
                Text(instanceURLValidationMessage)
                    .font(.footnote)
                    .foregroundStyle(.red.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(AppConstants.Copy.fediverseServerDescription)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            
            Button(action: onSignInTap) {
                HStack(spacing: 8) {
                    if isSigningIn {
                        ProgressView().tint(.white)
                    }

                    Text("Sign in")
                        .bold()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(.white)
            }
            .buttonStyle(.glassProminent)
            .opacity(isActionInProgress ? 0.72 : 1)
            .disabled(isActionInProgress)
            
            HStack(spacing: 12) {
                Rectangle()
                    .fill(.white.opacity(0.18))
                    .frame(maxWidth: .infinity)
                    .frame(height: 1)

                Text("OR")
                    .font(.footnote.bold())
                    .foregroundStyle(.white.opacity(0.70))

                Rectangle()
                    .fill(.white.opacity(0.18))
                    .frame(maxWidth: .infinity)
                    .frame(height: 1)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            
            Button(action: onCreateAccountTap) {
                HStack(spacing: 8) {
                    if isPreparingRegistration {
                        ProgressView().tint(.white)
                    } else {
                        Text("Create account")
                            .bold()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.glass)
            .opacity(isActionInProgress ? 0.72 : 1)
            .disabled(isActionInProgress)
            .highPriorityGesture(
                TapGesture().onEnded {
                    onCreateAccountTap()
                }
            )
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
            } else if filteredCuratedInstances.isEmpty {
                Text("No suggested servers match your URL filter.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            } else {
                ForEach(filteredCuratedInstances) { instance in
                    CuratedInstanceCardView(instance: instance) {
                        instanceURL = instanceURLWithoutScheme(instance.url)
                        isInstanceURLFocused = false
                    }
                }
            }
        }
    }

    private func onSignInTap() {
        guard !isActionInProgress else {
            return
        }

        isInstanceURLFocused = false
        Task {
            await signIn()
        }
    }
    
    private func onCreateAccountTap() {
        guard !isActionInProgress else {
            return
        }

        guard registrationDestination == nil else {
            return
        }

        guard validateInstanceURLPresence() else {
            return
        }

        isInstanceURLFocused = false
        isPreparingRegistration = true
        Task {
            await prepareRegistration()
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
        guard validateInstanceURLPresence() else {
            return
        }

        isSigningIn = true
        defer { isSigningIn = false }

        do {
            let sanitizedInstanceURL = try sanitizeEnteredInstanceURL()
            try await appState.signIn(instanceURLString: sanitizedInstanceURL.absoluteString)
            errorMessage = nil
            onDone?()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    @MainActor
    private func prepareRegistration() async {
        defer { isPreparingRegistration = false }

        do {
            let sanitizedInstanceURL = try sanitizeEnteredInstanceURL()
            async let fetchedInstanceDetails = RegistrationAPI.fetchInstanceDetails(at: sanitizedInstanceURL)
            async let fetchedPublicSettings = RegistrationAPI.fetchPublicSettings(at: sanitizedInstanceURL)

            registrationDestination = RegistrationDestination(
                instanceURL: sanitizedInstanceURL,
                instanceDetails: try await fetchedInstanceDetails,
                publicSettings: try await fetchedPublicSettings
            )
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = registrationErrorMessage(for: error)
        }
    }

    private func registrationErrorMessage(for error: Error) -> String {
        if case .decoding = (error as? APIError) {
            return AppConstants.Copy.unsupportedServerResponse
        }

        return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    private func sanitizeEnteredInstanceURL() throws -> URL {
        try URLSanitizer.sanitizeBaseURL(instanceURL)
    }

    private func validateInstanceURLPresence() -> Bool {
        let trimmed = instanceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showsInstanceURLRequiredError = true
            return false
        }

        showsInstanceURLRequiredError = false
        return true
    }

    private func normalizeInstanceURLForMatching(_ value: String) -> String {
        instanceURLWithoutScheme(value).lowercased()
    }

    private func instanceURLWithoutScheme(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()

        if lowered.hasPrefix("https://") {
            return String(trimmed.dropFirst("https://".count))
        }

        if lowered.hasPrefix("http://") {
            return String(trimmed.dropFirst("http://".count))
        }

        return trimmed
    }
}
