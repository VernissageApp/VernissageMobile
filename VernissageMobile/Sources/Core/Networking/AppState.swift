//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    private(set) var accounts: [StoredAccount] = []
    private(set) var activeAccountID: UUID?
    private(set) var unreadNotificationsCount = 0
    @ObservationIgnored private(set) var api: APIServiceContainer!

    var errorToastMessage: String?
    var warningToastMessage: String?
    var infoToastMessage: String?
    var successToastMessage: String?

    private var inactiveAccountsRefreshTask: Task<Void, Never>?

    var activeAccount: StoredAccount? {
        guard let activeAccountID else {
            return nil
        }

        return accounts.first(where: { $0.id == activeAccountID })
    }

    var activeTokenRoles: Set<String> {
        guard let token = activeAccount?.accessToken,
              let claims = JWTInspector.decodeClaims(from: token) else {
            return []
        }

        return Set((claims.roles ?? []).map { $0.lowercased() })
    }

    private let accountsKey = "accounts-json"
    private let activeAccountDefaultsKey = "active-account-id"
    private static let appGroupIdentifier = "group.photos.vernissage.ios"
    private static let proactiveAccessTokenRefreshThreshold: TimeInterval = 2 * 24 * 60 * 60
    private let sharedDefaults = UserDefaults(suiteName: AppState.appGroupIdentifier)

    private let oauthCoordinator = OAuthCoordinator()
    private struct APIErrorBody: Decodable {
        let code: String
    }

    init() {
        self.api = APIServiceContainer(appState: self)
        loadFromStorage()
    }

    func signIn(instanceURLString: String) async throws {
        let instanceURL = try URLSanitizer.sanitizeBaseURL(instanceURLString)

        let registration = try await OAuthAPI.registerClient(at: instanceURL,
                                                             redirectURI: AppConstants.OAuth.redirectURI,
                                                             scope: AppConstants.OAuth.scope)

        let code = try await oauthCoordinator.authorize(
            baseURL: instanceURL,
            clientID: registration.clientId,
            redirectURI: AppConstants.OAuth.redirectURI,
            scope: AppConstants.OAuth.scope
        )

        let token = try await OAuthAPI.exchangeCode(
            at: instanceURL,
            code: code,
            clientID: registration.clientId,
            clientSecret: registration.clientSecret,
            redirectURI: AppConstants.OAuth.redirectURI
        )

        guard let claims = JWTInspector.decodeClaims(from: token.accessToken),
              let userName = claims.userName?.nilIfEmpty else {
            throw APIError.invalidTokenPayload
        }

        var account = StoredAccount(
            id: existingAccountID(instanceURL: instanceURL.absoluteString, userName: userName) ?? UUID(),
            instanceURL: instanceURL.absoluteString,
            clientID: registration.clientId,
            clientSecret: registration.clientSecret,
            accessToken: token.accessToken,
            refreshToken: token.refreshToken,
            accessTokenExpiration: token.expirationDate ?? claims.expiration,
            userName: userName,
            displayName: claims.name,
            avatarURL: nil
        )

        if let downloadedProfile = try? await api.users.fetchProfile(for: account) {
            account.displayName = downloadedProfile.name?.nilIfEmpty ?? account.displayName
            account.avatarURL = downloadedProfile.avatarUrl?.nilIfEmpty
        }

        upsertAccount(account)
        activateAccount(id: account.id)
    }

    func activateAccount(id: UUID) {
        guard accounts.contains(where: { $0.id == id }) else {
            return
        }

        activeAccountID = id
        saveToStorage()
    }

    func removeAccount(id: UUID) {
        accounts.removeAll(where: { $0.id == id })

        if activeAccountID == id {
            activeAccountID = accounts.first?.id
        }

        if accounts.isEmpty {
            unreadNotificationsCount = 0
        }

        saveToStorage()
    }

    func refreshActiveTokenIfNeeded(force: Bool) async {
        guard var account = activeAccount else {
            return
        }

        if !force,
           let expiration = account.accessTokenExpiration,
           expiration.timeIntervalSinceNow > Self.proactiveAccessTokenRefreshThreshold {
            return
        }

        guard let refreshToken = account.refreshToken else {
            return
        }

        do {
            let refreshed = try await OAuthAPI.refreshToken(
                at: URLSanitizer.sanitizeBaseURL(account.instanceURL),
                refreshToken: refreshToken,
                clientID: account.clientID,
                clientSecret: account.clientSecret
            )

            account.accessToken = refreshed.accessToken
            account.refreshToken = refreshed.refreshToken ?? account.refreshToken
            account.accessTokenExpiration = refreshed.expirationDate ?? account.accessTokenExpiration

            upsertAccount(account)
        } catch {
            if handleRefreshFailureForReauthenticationIfNeeded(error, account: account) {
                return
            }

            showErrorToast((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    func scheduleInactiveAccountsTokenRefreshIfNeeded() {
        inactiveAccountsRefreshTask?.cancel()
        inactiveAccountsRefreshTask = Task(priority: .background) { [weak self] in
            await self?.refreshInactiveAccountsTokensIfNeeded()
        }
    }

    func requireActiveAccount() throws -> StoredAccount {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        return account
    }

    func refreshUnreadNotificationsCount() async {
        guard activeAccount != nil else {
            unreadNotificationsCount = 0
            return
        }

        do {
            let count = try await api.notifications.fetchNotificationsCount()
            self.unreadNotificationsCount = max(0, count.amount ?? 0)
        } catch {
            // Keep the current badge state when counter refresh fails.
        }
    }

    func showErrorToast(_ message: String) {
        setToastMessage(message, keyPath: \.errorToastMessage)
    }

    func showWarningToast(_ message: String) {
        setToastMessage(message, keyPath: \.warningToastMessage)
    }

    func showInfoToast(_ message: String) {
        setToastMessage(message, keyPath: \.infoToastMessage)
    }

    func showSuccessToast(_ message: String) {
        setToastMessage(message, keyPath: \.successToastMessage)
    }

    private func setToastMessage(_ message: String, keyPath: ReferenceWritableKeyPath<AppState, String?>) {
        guard let presentableMessage = message.toastPresentableMessage else {
            return
        }

        if self[keyPath: keyPath] == presentableMessage {
            self[keyPath: keyPath] = nil
        }

        self[keyPath: keyPath] = presentableMessage
    }

    func fetchActiveProfile() async throws -> User {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let profile = try await api.users.fetchProfile(for: account)
        syncActiveAccount(using: profile)
        return profile
    }

    func updateActiveProfile(request profileUpdateRequest: UpdateProfileRequest) async throws -> User {
        let updatedUser = try await api.users.updateActiveProfile(request: profileUpdateRequest)

        syncActiveAccount(using: updatedUser)

        return updatedUser
    }

    func uploadActiveAvatar(imageData: Data, fileName: String = "avatar.jpg", mimeType: String = "image/jpeg") async throws -> User {
        try await api.users.uploadActiveAvatar(imageData: imageData, fileName: fileName, mimeType: mimeType)
        return try await fetchActiveProfile()
    }

    func deleteActiveAvatar() async throws -> User {
        try await api.users.deleteActiveAvatar()
        return try await fetchActiveProfile()
    }

    func uploadActiveHeader(imageData: Data, fileName: String = "header.jpg", mimeType: String = "image/jpeg") async throws -> User {
        try await api.users.uploadActiveHeader(imageData: imageData, fileName: fileName, mimeType: mimeType)
        return try await fetchActiveProfile()
    }

    func deleteActiveHeader() async throws -> User {
        try await api.users.deleteActiveHeader()
        return try await fetchActiveProfile()
    }

    func refreshAccessToken(for account: StoredAccount) async throws -> StoredAccount? {
        guard let refreshToken = account.refreshToken else {
            return nil
        }

        let refreshed: OAuthTokenResponse
        do {
            refreshed = try await OAuthAPI.refreshToken(
                at: URLSanitizer.sanitizeBaseURL(account.instanceURL),
                refreshToken: refreshToken,
                clientID: account.clientID,
                clientSecret: account.clientSecret
            )
        } catch {
            if handleRefreshFailureForReauthenticationIfNeeded(error, account: account) {
                return nil
            }

            throw error
        }

        var updated = account
        updated.accessToken = refreshed.accessToken
        updated.refreshToken = refreshed.refreshToken ?? account.refreshToken
        updated.accessTokenExpiration = refreshed.expirationDate ?? account.accessTokenExpiration

        upsertAccount(updated)
        return updated
    }

    private func refreshInactiveAccountsTokensIfNeeded() async {
        let accountIds = accounts.map(\.id)

        for accountId in accountIds {
            guard !Task.isCancelled else {
                return
            }

            guard accountId != activeAccountID,
                  var account = accounts.first(where: { $0.id == accountId }) else {
                continue
            }

            if let expiration = account.accessTokenExpiration,
               expiration.timeIntervalSinceNow > Self.proactiveAccessTokenRefreshThreshold {
                continue
            }

            guard let refreshToken = account.refreshToken else {
                continue
            }

            do {
                let refreshed = try await OAuthAPI.refreshToken(
                    at: URLSanitizer.sanitizeBaseURL(account.instanceURL),
                    refreshToken: refreshToken,
                    clientID: account.clientID,
                    clientSecret: account.clientSecret
                )

                account.accessToken = refreshed.accessToken
                account.refreshToken = refreshed.refreshToken ?? account.refreshToken
                account.accessTokenExpiration = refreshed.expirationDate ?? account.accessTokenExpiration
                upsertAccount(account)
            } catch {
                // Keep this refresh silent for inactive accounts.
                continue
            }
        }
    }

    @discardableResult
    private func handleRefreshFailureForReauthenticationIfNeeded(_ error: Error, account: StoredAccount) -> Bool {
        guard shouldForceReauthentication(for: error) else {
            return false
        }

        invalidateSessionAndRequireReauthentication(for: account.id)
        showWarningToast("The session for @\(account.userName) has expired. Please sign in to this account again.")
        return true
    }

    private func shouldForceReauthentication(for error: Error) -> Bool {
        guard case let APIError.http(statusCode, body) = error,
              let errorCode = extractAPIErrorCode(from: body)?.lowercased() else {
            return false
        }

        if statusCode == 404 {
            return errorCode == "refreshtokennotfound"
        }

        if statusCode == 403 {
            return errorCode == "refreshtokenrevoked" || errorCode == "refreshtokenexpired"
        }

        return false
    }

    private func extractAPIErrorCode(from body: String) -> String? {
        guard let data = body.data(using: .utf8),
              let errorBody = try? JSONDecoder().decode(APIErrorBody.self, from: data) else {
            return nil
        }

        return errorBody.code.nilIfEmpty
    }

    private func invalidateSessionAndRequireReauthentication(for accountID: UUID) {
        accounts.removeAll(where: { $0.id == accountID })

        if activeAccountID == accountID {
            activeAccountID = accounts.first?.id
            if activeAccountID == nil {
                unreadNotificationsCount = 0
            }
        }

        saveToStorage()
    }

    private func loadFromStorage() {
        if let raw = sharedDefaults?.string(forKey: activeAccountDefaultsKey),
           let id = UUID(uuidString: raw) {
            activeAccountID = id
        }

        let sharedData = sharedDefaults?.data(forKey: accountsKey)
        if let decoded = decodeAccounts(from: sharedData) {
            accounts = decoded
        } else {
            accounts = []
        }

        if activeAccountID == nil || !accounts.contains(where: { $0.id == activeAccountID }) {
            activeAccountID = accounts.first?.id
        }
    }

    private func saveToStorage() {
        let encoded: Data
        do {
            encoded = try JSONEncoder().encode(accounts)
        } catch {
            showErrorToast("Cannot encode accounts.")
            return
        }

        sharedDefaults?.set(encoded, forKey: accountsKey)

        if let activeAccountID {
            sharedDefaults?.set(activeAccountID.uuidString, forKey: activeAccountDefaultsKey)
        } else {
            sharedDefaults?.removeObject(forKey: activeAccountDefaultsKey)
        }
    }

    private func decodeAccounts(from data: Data?) -> [StoredAccount]? {
        guard let data else {
            return nil
        }

        return try? JSONDecoder().decode([StoredAccount].self, from: data)
    }

    private func existingAccountID(instanceURL: String, userName: String) -> UUID? {
        accounts.first {
            $0.instanceURL.caseInsensitiveCompare(instanceURL) == .orderedSame &&
            $0.userName.caseInsensitiveCompare(userName) == .orderedSame
        }?.id
    }

    private func upsertAccount(_ account: StoredAccount) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
        } else {
            accounts.append(account)
        }

        saveToStorage()
    }

    private func syncActiveAccount(using profile: User) {
        guard var account = activeAccount else {
            return
        }

        account.displayName = profile.name?.nilIfEmpty ?? account.displayName
        account.avatarURL = profile.avatarUrl?.nilIfEmpty
        upsertAccount(account)
    }
}
