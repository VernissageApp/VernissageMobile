//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct RegisterAccountScreen: View {
    private enum Field: Hashable {
        case userName
        case email
        case name
        case password
        case inviteToken
        case reason
        case captcha
    }

    private enum LocaleOption: String, CaseIterable, Identifiable {
        case english = "en_US"
        case polish = "pl_PL"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .english:
                return "English (English)"
            case .polish:
                return "Polish (polski)"
            }
        }
    }

    private enum AvailabilityState: Equatable {
        case idle
        case checking
        case available
        case unavailable(String)
    }

    private struct PasswordRequirements {
        let hasValidLength: Bool
        let hasLowercase: Bool
        let hasUppercase: Bool
        let hasNumberOrSymbol: Bool

        var isValid: Bool {
            hasValidLength && hasLowercase && hasUppercase && hasNumberOrSymbol
        }
    }

    private static let emailPattern = #"^[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$"#
    private static let userNameAllowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")

    @Environment(\.dismiss) private var dismiss

    let instanceURL: URL
    var onRegistered: ((String) -> Void)? = nil

    @State private var userName = ""
    @State private var email = ""
    @State private var name = ""
    @State private var locale = LocaleOption.english
    @State private var password = ""
    @State private var agreement = false
    @State private var inviteToken = ""
    @State private var reason = ""
    @State private var captchaText = ""
    @State private var captchaKey = RegisterAccountScreen.generateCaptchaKey(length: 16)

    @State private var instanceDetails: InstanceDetails
    @State private var publicSettings: PublicSettings
    @State private var isSubmitting = false
    @State private var generalErrorMessage: String?

    @State private var didAttemptSubmit = false
    @State private var usernameAvailability: AvailabilityState = .idle
    @State private var emailAvailability: AvailabilityState = .idle
    @State private var emailServerMessage: String?
    @State private var nameServerMessage: String?
    @State private var agreementErrorMessage: String?
    @State private var inviteErrorMessage: String?
    @State private var reasonErrorMessage: String?
    @State private var captchaErrorMessage: String?

    @State private var isPasswordVisible = false
    @State private var usernameValidationTask: Task<Void, Never>?
    @State private var emailValidationTask: Task<Void, Never>?
    @FocusState private var focusedField: Field?

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

    private var secondaryTextColor: Color {
        .white.opacity(0.78)
    }

    private var warningColor: Color {
        Color.orange.opacity(0.95)
    }

    private var hostName: String {
        instanceURL.host ?? instanceURL.absoluteString
    }

    private var registrationOpened: Bool {
        instanceDetails.registrationOpened == true
    }

    private var registrationByApprovalOpened: Bool {
        instanceDetails.registrationByApprovalOpened == true
    }

    private var registrationByInvitationsOpened: Bool {
        instanceDetails.registrationByInvitationsOpened == true
    }

    private var isRegistrationEnabled: Bool {
        registrationOpened || registrationByApprovalOpened || registrationByInvitationsOpened
    }

    private var showsInvitationField: Bool {
        !registrationOpened && registrationByInvitationsOpened
    }

    private var showsReasonField: Bool {
        !registrationOpened && registrationByApprovalOpened
    }

    private var showsCaptcha: Bool {
        isRegistrationEnabled && publicSettings.isQuickCaptchaEnabled == true
    }

    private var isInteractionDisabled: Bool {
        isSubmitting || !isRegistrationEnabled
    }

    private var serverRules: [InstanceRule] {
        instanceDetails.rules ?? []
    }

    private var requiresInvitationCode: Bool {
        showsInvitationField && !showsReasonField
    }

    private var requiresReason: Bool {
        showsReasonField && !showsInvitationField
    }

    private var passwordRequirements: PasswordRequirements {
        let value = password

        return PasswordRequirements(
            hasValidLength: (8...32).contains(value.count),
            hasLowercase: value.contains(where: \.isLowercase),
            hasUppercase: value.contains(where: \.isUppercase),
            hasNumberOrSymbol: value.contains { $0.isNumber || (!$0.isLetter && !$0.isWhitespace) }
        )
    }

    private var captchaImageURL: URL? {
        RegistrationAPI.captchaImageURL(baseURL: instanceURL, key: captchaKey)
    }

    private var nextFieldAfterPassword: Field? {
        if showsInvitationField {
            return .inviteToken
        }

        if showsReasonField {
            return .reason
        }

        if showsCaptcha {
            return .captcha
        }

        return nil
    }

    private var nextFieldAfterInvitation: Field? {
        if showsReasonField {
            return .reason
        }

        if showsCaptcha {
            return .captcha
        }

        return nil
    }

    init(
        instanceURL: URL,
        instanceDetails: InstanceDetails,
        publicSettings: PublicSettings,
        onRegistered: ((String) -> Void)? = nil
    ) {
        self.instanceURL = instanceURL
        self.onRegistered = onRegistered
        _instanceDetails = State(initialValue: instanceDetails)
        _publicSettings = State(initialValue: publicSettings)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !isRegistrationEnabled {
                        registrationDisabledCard
                    }

                    headerCard

                    accountDetailsCard
                        .disabled(isInteractionDisabled)

                    passwordCard
                        .disabled(isInteractionDisabled)

                    serverRulesCard
                        .disabled(isInteractionDisabled)

                    if showsInvitationField || showsReasonField {
                        accessRequirementsCard
                            .disabled(isInteractionDisabled)
                    }

                    if showsCaptcha {
                        captchaCard
                            .disabled(isInteractionDisabled)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .background(
                screenBackgroundGradient
                    .ignoresSafeArea()
            )
            .navigationTitle("Create account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        focusedField = nil
                        Task {
                            await submitRegistration()
                        }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Register")
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(isInteractionDisabled)
                }
            }
        }
        .preferredColorScheme(.dark)
        .errorAlertToast($generalErrorMessage)
        .onDisappear {
            usernameValidationTask?.cancel()
            emailValidationTask?.cancel()
        }
        .onChange(of: userName) { _, newValue in
            scheduleUserNameAvailabilityCheck(for: newValue)
        }
        .onChange(of: email) { _, newValue in
            scheduleEmailAvailabilityCheck(for: newValue)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Create your account on \(hostName)")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("Choose your account details, review the server rules, and complete any extra requirements this server asks for.")
                .font(.subheadline)
                .foregroundStyle(secondaryTextColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(cardBackground)
        .overlay(cardStroke)
    }

    private var registrationDisabledCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(warningColor)
                .font(.title3)

            VStack(alignment: .leading, spacing: 6) {
                Text("Registration is currently disabled on this server.")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("You can still choose a different server or return and sign in to an existing account.")
                    .font(.subheadline)
                    .foregroundStyle(secondaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.orange.opacity(0.32), lineWidth: 1)
        )
    }

    private var accountDetailsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Account details")
                .font(.headline)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("Username")

                HStack(spacing: 12) {
                    Text("@")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.62))
                        .accessibilityHidden(true)

                    TextField("johndoe", text: $userName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.username)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .userName)
                        .onSubmit {
                            focusedField = .email
                        }
                        .accessibilityLabel("Username")

                    Group {
                        if case .checking = usernameAvailability {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white.opacity(0.76))
                                .accessibilityLabel("Checking username availability")
                        }
                    }
                    .frame(width: 18, alignment: .center)

                    Text("@\(hostName)")
                        .font(.footnote)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(.white.opacity(0.62))
                        .accessibilityHidden(true)
                }
                .modifier(
                    RegistrationFieldStyle(
                        fillColor: fieldFillColor,
                        strokeColor: strokeColorForField(hasError: usernameErrorMessage(showRequired: didAttemptSubmit) != nil)
                    )
                )

                if let message = usernameErrorMessage(showRequired: didAttemptSubmit) {
                    validationMessage(message)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("Email")

                HStack(spacing: 12) {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .email)
                        .onSubmit {
                            focusedField = .name
                        }

                    if case .checking = emailAvailability {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white.opacity(0.76))
                            .accessibilityLabel("Checking email availability")
                    }
                }
                .modifier(
                    RegistrationFieldStyle(
                        fillColor: fieldFillColor,
                        strokeColor: strokeColorForField(hasError: emailErrorMessage(showRequired: didAttemptSubmit) != nil)
                    )
                )

                if let message = emailErrorMessage(showRequired: didAttemptSubmit) {
                    validationMessage(message)
                }

                Text("Don't worry. This info is sacred for us. We won't ever show, sell or abuse it.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("Display name")

                TextField("Display name", text: $name)
                    .textContentType(.name)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .name)
                    .onSubmit {
                        focusedField = .password
                    }
                    .modifier(
                        RegistrationFieldStyle(
                            fillColor: fieldFillColor,
                            strokeColor: strokeColorForField(hasError: nameErrorMessage(showRequired: didAttemptSubmit) != nil)
                        )
                    )

                if let message = nameErrorMessage(showRequired: didAttemptSubmit) {
                    validationMessage(message)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("Language")

                Picker("Language", selection: $locale) {
                    ForEach(LocaleOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .tint(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(fieldFillColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(fieldStrokeColor, lineWidth: 1)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(cardBackground)
        .overlay(cardStroke)
    }

    private var passwordCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Password")
                .font(.headline)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("Password")

                HStack(spacing: 12) {
                    Group {
                        if isPasswordVisible {
                            TextField("Password", text: $password)
                        } else {
                            SecureField("Password", text: $password)
                        }
                    }
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.newPassword)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .password)
                    .onSubmit {
                        focusedField = nextFieldAfterPassword
                    }

                    Button {
                        isPasswordVisible.toggle()
                    } label: {
                        Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.76))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password")
                }
                .modifier(
                    RegistrationFieldStyle(
                        fillColor: fieldFillColor,
                        strokeColor: strokeColorForField(hasError: passwordErrorMessage(showRequired: didAttemptSubmit) != nil)
                    )
                )

                if let message = passwordErrorMessage(showRequired: didAttemptSubmit) {
                    validationMessage(message)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                passwordRequirementRow("Between 8 and 32 characters long", isMet: passwordRequirements.hasValidLength)
                passwordRequirementRow("One lowercase letter", isMet: passwordRequirements.hasLowercase)
                passwordRequirementRow("One uppercase letter", isMet: passwordRequirements.hasUppercase)
                passwordRequirementRow("Number or symbol", isMet: passwordRequirements.hasNumberOrSymbol)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(cardBackground)
        .overlay(cardStroke)
    }

    private var serverRulesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Server rules")
                .font(.headline)
                .foregroundStyle(.white)

            if serverRules.isEmpty {
                Text("No additional server rules were provided, but you still need to accept this server's registration terms.")
                    .font(.subheadline)
                    .foregroundStyle(secondaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(serverRules) { rule in
                        HStack(alignment: .top, spacing: 10) {
                            Text("•")
                                .foregroundStyle(.white.opacity(0.88))

                            Text(rule.text)
                                .font(.subheadline)
                                .foregroundStyle(secondaryTextColor)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            Button {
                agreement.toggle()
                agreementErrorMessage = nil
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: agreement ? "checkmark.square.fill" : "square")
                        .font(.title3)
                        .foregroundStyle(agreement ? .blue : .white.opacity(0.72))

                    Text("I accept all server rules.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let agreementErrorMessage {
                validationMessage(agreementErrorMessage)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(cardBackground)
        .overlay(cardStroke)
    }

    private var accessRequirementsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Access requirements")
                .font(.headline)
                .foregroundStyle(.white)

            if showsInvitationField {
                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Invitation code")

                    TextField("Invitation code", text: $inviteToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(showsReasonField ? .next : (showsCaptcha ? .next : .done))
                        .focused($focusedField, equals: .inviteToken)
                        .onSubmit {
                            focusedField = nextFieldAfterInvitation
                        }
                        .modifier(
                            RegistrationFieldStyle(
                                fillColor: fieldFillColor,
                                strokeColor: strokeColorForField(hasError: inviteErrorMessage != nil)
                            )
                        )

                    if let inviteErrorMessage {
                        validationMessage(inviteErrorMessage)
                    }
                }
            }
            
            if showsInvitationField && showsReasonField {
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
            }

            if showsReasonField {
                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Reason")

                    TextField("Reason", text: $reason, axis: .vertical)
                        .lineLimit(3...6)
                        .submitLabel(showsCaptcha ? .next : .done)
                        .focused($focusedField, equals: .reason)
                        .onSubmit {
                            focusedField = showsCaptcha ? .captcha : nil
                        }
                        .modifier(
                            RegistrationFieldStyle(
                                fillColor: fieldFillColor,
                                strokeColor: strokeColorForField(hasError: reasonErrorMessage != nil)
                            )
                        )

                    if let reasonErrorMessage {
                        validationMessage(reasonErrorMessage)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(cardBackground)
        .overlay(cardStroke)
    }

    private var captchaCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Solve the captcha")
                .font(.headline)
                .foregroundStyle(.white)
            
            
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 12) {
                    captchaImageView
                    
                    Button("Refresh") {
                        refreshCaptcha()
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                }
                
                TextField("Captcha text", text: $captchaText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($focusedField, equals: .captcha)
                    .modifier(
                        RegistrationFieldStyle(
                            fillColor: fieldFillColor,
                            strokeColor: strokeColorForField(hasError: captchaErrorMessage != nil)
                        )
                    )
                
                if let captchaErrorMessage {
                    validationMessage(captchaErrorMessage)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(cardBackground)
        .overlay(cardStroke)
    }
    
    private var captchaImageView: some View {
        Group {
            if let captchaImageURL {
                AsyncImage(url: captchaImageURL, transaction: Transaction(animation: .easeInOut(duration: 0.2))) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .failure:
                        captchaPlaceholder(message: "Captcha unavailable")
                    case .empty:
                        captchaPlaceholder(message: "Loading captcha...")
                    @unknown default:
                        captchaPlaceholder(message: "Captcha unavailable")
                    }
                }
            } else {
                captchaPlaceholder(message: "Captcha unavailable")
            }
        }
        .frame(maxWidth: .infinity, minHeight: 90, maxHeight: 90)
        .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func captchaPlaceholder(message: String) -> some View {
        ZStack {
            Color.white
            Text(message)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.black.opacity(0.55))
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.white.opacity(0.08))
    }

    private var cardStroke: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(fieldStrokeColor, lineWidth: 1)
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(fieldLabelColor)
    }

    private func validationMessage(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.red.opacity(0.92))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func strokeColorForField(hasError: Bool) -> Color {
        hasError ? fieldErrorStrokeColor : fieldStrokeColor
    }

    private func passwordRequirementRow(_ title: String, isMet: Bool) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .font(.footnote)
                .foregroundStyle(isMet ? Color(red: 0.10, green: 0.74, blue: 0.36) : .white.opacity(0.45))

            Text(title)
                .font(.footnote)
                .foregroundStyle(.white.opacity(isMet ? 0.85 : 0.58))
        }
    }

    private func scheduleUserNameAvailabilityCheck(for newValue: String) {
        usernameValidationTask?.cancel()
        usernameAvailability = .idle

        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canCheckUserNameAvailability(for: trimmed) else {
            return
        }

        usernameValidationTask = Task {
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else {
                return
            }

            _ = await performUserNameAvailabilityCheck(for: trimmed)
        }
    }

    private func scheduleEmailAvailabilityCheck(for newValue: String) {
        emailValidationTask?.cancel()
        emailAvailability = .idle
        emailServerMessage = nil

        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canCheckEmailAvailability(for: trimmed) else {
            return
        }

        emailValidationTask = Task {
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else {
                return
            }

            _ = await performEmailAvailabilityCheck(for: trimmed)
        }
    }

    @MainActor
    private func performUserNameAvailabilityCheck(for value: String) async -> Bool {
        guard canCheckUserNameAvailability(for: value) else {
            usernameAvailability = .idle
            return false
        }

        usernameAvailability = .checking

        do {
            let isTaken = try await RegistrationAPI.isUserNameTaken(value, at: instanceURL)
            guard sanitizedUserName == value else {
                return false
            }

            if isTaken {
                usernameAvailability = .unavailable("Choose a different user name, this one is already taken.")
                return false
            } else {
                usernameAvailability = .available
                return true
            }
        } catch is CancellationError {
            return false
        } catch {
            guard sanitizedUserName == value else {
                return false
            }

            usernameAvailability = .idle
            return true
        }
    }

    @MainActor
    private func performEmailAvailabilityCheck(for value: String) async -> Bool {
        guard canCheckEmailAvailability(for: value) else {
            emailAvailability = .idle
            return false
        }

        emailAvailability = .checking

        do {
            let isConnected = try await RegistrationAPI.isEmailConnected(value, at: instanceURL)
            guard sanitizedEmail == value else {
                return false
            }

            if isConnected {
                emailAvailability = .unavailable("Choose other email, this one is already connected to different account.")
                return false
            } else {
                emailAvailability = .available
                return true
            }
        } catch is CancellationError {
            return false
        } catch {
            guard sanitizedEmail == value else {
                return false
            }

            emailAvailability = .idle
            return true
        }
    }

    @MainActor
    private func submitRegistration() async {
        guard !isSubmitting else {
            return
        }

        didAttemptSubmit = true
        clearSubmissionMessages()

        let hasLocalValidationPassed = await validateFieldsBeforeSubmit()
        guard hasLocalValidationPassed else {
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        let request = RegisterUserRequest(
            userName: sanitizedUserName,
            email: sanitizedEmail,
            password: password,
            name: sanitizedName.nilIfEmpty,
            securityToken: showsCaptcha ? "\(captchaKey)/\(sanitizedCaptchaText)" : "",
            inviteToken: sanitizedInviteToken.nilIfEmpty,
            redirectBaseUrl: instanceURL.absoluteString,
            agreement: agreement,
            locale: locale.rawValue,
            reason: sanitizedReason.nilIfEmpty
        )

        do {
            _ = try await RegistrationAPI.register(request, at: instanceURL)
            onRegistered?("Your account has been created. Sign in to continue. ")
            dismiss()
        } catch let serverError as RegistrationAPI.ServerError {
            applyServerValidation(serverError)
        } catch {
            generalErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    @MainActor
    private func validateFieldsBeforeSubmit() async -> Bool {
        var isValid = true

        if usernameErrorMessage(showRequired: true) != nil {
            isValid = false
        } else if await validateUserNameAvailabilityForSubmit() == false {
            isValid = false
        }

        if emailErrorMessage(showRequired: true) != nil {
            isValid = false
        } else if await validateEmailAvailabilityForSubmit() == false {
            isValid = false
        }

        if nameErrorMessage(showRequired: true) != nil {
            isValid = false
        }

        if passwordErrorMessage(showRequired: true) != nil {
            isValid = false
        }

        if agreement == false {
            agreementErrorMessage = "You have to accept server rules."
            isValid = false
        }

        if showsInvitationField {
            if requiresInvitationCode && sanitizedInviteToken.isEmpty {
                inviteErrorMessage = "Enter invitation code."
                isValid = false
            } else {
                inviteErrorMessage = nil
            }
        }

        if showsReasonField {
            if requiresReason && sanitizedReason.isEmpty {
                reasonErrorMessage = "Enter reason."
                isValid = false
            } else if sanitizedReason.count > 500 {
                reasonErrorMessage = "Reason is too long."
                isValid = false
            } else {
                reasonErrorMessage = nil
            }
        }

        if showsCaptcha {
            if sanitizedCaptchaText.isEmpty {
                captchaErrorMessage = "Enter captcha text."
                isValid = false
            } else if sanitizedCaptchaText.count > 6 {
                captchaErrorMessage = "Captcha text is too long."
                isValid = false
            } else {
                captchaErrorMessage = nil
            }
        }

        return isValid
    }

    @MainActor
    private func validateUserNameAvailabilityForSubmit() async -> Bool {
        switch usernameAvailability {
        case .available:
            return true
        case .unavailable:
            return false
        case .checking, .idle:
            return await performUserNameAvailabilityCheck(for: sanitizedUserName)
        }
    }

    @MainActor
    private func validateEmailAvailabilityForSubmit() async -> Bool {
        switch emailAvailability {
        case .available:
            return true
        case .unavailable:
            return false
        case .checking, .idle:
            return await performEmailAvailabilityCheck(for: sanitizedEmail)
        }
    }

    @MainActor
    private func applyServerValidation(_ error: RegistrationAPI.ServerError) {
        let normalizedCode = error.code?.lowercased()

        switch normalizedCode {
        case "usernameisalreadytaken":
            usernameAvailability = .unavailable("Choose a different user name, this one is already taken.")
        case "emailisalreadyconnected":
            emailAvailability = .unavailable("Choose other email, this one is already connected to different account.")
        case "userhavetoacceptagreement":
            agreementErrorMessage = "You have to accept server rules."
        case "disposableemailcannotbeused":
            emailServerMessage = "Disposable email cannot be used."
        case "securitytokenisinvalid":
            captchaErrorMessage = "Captcha code is invalid. Please try again."
            refreshCaptcha()
        case "invitationtokenisinvalid":
            inviteErrorMessage = "Invitation code is invalid."
        case "invitationtokenhasbeenused":
            inviteErrorMessage = "Invitation code has already been used."
        case "reasonismandatory":
            reasonErrorMessage = "Enter reason."
        case "registrationisdisabled":
            generalErrorMessage = "Registration is currently disabled on this server."
            instanceDetails = InstanceDetails(
                uri: instanceDetails.uri,
                title: instanceDetails.title,
                description: instanceDetails.description,
                longDescription: instanceDetails.longDescription,
                email: instanceDetails.email,
                version: instanceDetails.version,
                thumbnail: instanceDetails.thumbnail,
                languages: instanceDetails.languages,
                registrationOpened: false,
                registrationByApprovalOpened: false,
                registrationByInvitationsOpened: false,
                configuration: instanceDetails.configuration,
                contact: instanceDetails.contact,
                rules: instanceDetails.rules
            )
        case "validationerror":
            applyValidationFailures(error.failures)
        default:
            if applyValidationFailures(error.failures) == false {
                generalErrorMessage = error.errorDescription
            }
        }
    }

    @discardableResult
    @MainActor
    private func applyValidationFailures(_ failures: [RegistrationAPI.ServerError.Failure]) -> Bool {
        var handledFailure = false

        for failure in failures {
            let field = failure.field?.lowercased() ?? ""
            let message = failure.failure?.lowercased() ?? ""

            switch field {
            case "username":
                handledFailure = true

                if message.contains("alphanumeric") {
                    usernameAvailability = .unavailable("Only alphanumeric characters are allowed in user name.")
                } else if message.contains("50") || message.contains("count") {
                    usernameAvailability = .unavailable("Choose a different user name, this one is too long.")
                }
            case "email":
                handledFailure = true

                if message.contains("email") {
                    emailServerMessage = "Verify that you've entered proper email."
                }
            case "name":
                handledFailure = true
                nameServerMessage = "Name is too long."
            case "reason":
                handledFailure = true
                reasonErrorMessage = message.contains("empty") ? "Enter reason." : "Reason is too long."
            case "securitytoken":
                handledFailure = true
                captchaErrorMessage = "Captcha code is invalid. Please try again."
            default:
                continue
            }
        }

        return handledFailure
    }

    @MainActor
    private func clearSubmissionMessages() {
        generalErrorMessage = nil
        emailServerMessage = nil
        nameServerMessage = nil
        agreementErrorMessage = nil
        inviteErrorMessage = nil
        reasonErrorMessage = nil
        captchaErrorMessage = nil
    }

    @MainActor
    private func refreshCaptcha() {
        captchaKey = RegisterAccountScreen.generateCaptchaKey(length: 16)
        captchaText = ""
        captchaErrorMessage = nil
    }

    private var sanitizedUserName: String {
        userName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var sanitizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var sanitizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var sanitizedInviteToken: String {
        inviteToken.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var sanitizedReason: String {
        reason.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var sanitizedCaptchaText: String {
        captchaText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func usernameErrorMessage(showRequired: Bool) -> String? {
        let value = sanitizedUserName

        if value.isEmpty {
            return showRequired ? "Enter username." : nil
        }

        if value.count > 50 {
            return "Choose a different user name, this one is too long."
        }

        if !value.unicodeScalars.allSatisfy({ Self.userNameAllowedCharacters.contains($0) }) {
            return "Only alphanumeric characters are allowed in user name."
        }

        if case .unavailable(let message) = usernameAvailability {
            return message
        }

        return nil
    }

    private func emailErrorMessage(showRequired: Bool) -> String? {
        let value = sanitizedEmail

        if value.isEmpty {
            return showRequired ? "Enter email." : nil
        }

        if value.range(of: Self.emailPattern, options: [.regularExpression, .caseInsensitive]) == nil {
            return "Verify that you've entered proper email."
        }

        if let emailServerMessage {
            return emailServerMessage
        }

        if case .unavailable(let message) = emailAvailability {
            return message
        }

        return nil
    }

    private func nameErrorMessage(showRequired: Bool) -> String? {
        let value = sanitizedName

        if value.isEmpty {
            return showRequired ? "Enter name." : nil
        }

        if value.count > 100 {
            return "Name is too long."
        }

        if let nameServerMessage {
            return nameServerMessage
        }

        return nil
    }

    private func passwordErrorMessage(showRequired: Bool) -> String? {
        if password.isEmpty && !showRequired {
            return nil
        }

        return passwordRequirements.isValid ? nil : "Your password have to fullfil below requirements."
    }

    private func canCheckUserNameAvailability(for value: String) -> Bool {
        !value.isEmpty
            && value.count <= 50
            && value.unicodeScalars.allSatisfy({ Self.userNameAllowedCharacters.contains($0) })
    }

    private func canCheckEmailAvailability(for value: String) -> Bool {
        !value.isEmpty
            && value.range(of: Self.emailPattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func generateCaptchaKey(length: Int) -> String {
        let characters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        return String((0..<length).compactMap { _ in characters.randomElement() })
    }
}
