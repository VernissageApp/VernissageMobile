//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var accounts: [StoredAccount] = []
    @Published private(set) var activeAccountID: UUID?
    @Published private(set) var unreadNotificationsCount = 0
    @Published var globalErrorMessage: String?
    @Published var toastMessage: String?

    private var toastDismissTask: Task<Void, Never>?

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
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private struct APIErrorBody: Decodable {
        let code: String
    }
    private struct BooleanResponse: Decodable {
        let result: Bool
    }
    private struct ResendEmailConfirmationRequest: Encodable {
        let redirectBaseUrl: String
    }

    init() {
        loadFromStorage()
    }

    func signIn(instanceURLString: String) async throws {
        let instanceURL = try URLSanitizer.sanitizeBaseURL(instanceURLString)

        let registration = try await OAuthAPI.registerClient(at: instanceURL,
                                                             redirectURI: Self.oauthRedirectURI,
                                                             scope: Self.oauthScope)

        let code = try await oauthCoordinator.authorize(
            baseURL: instanceURL,
            clientID: registration.clientId,
            redirectURI: Self.oauthRedirectURI,
            scope: Self.oauthScope
        )

        let token = try await OAuthAPI.exchangeCode(
            at: instanceURL,
            code: code,
            clientID: registration.clientId,
            clientSecret: registration.clientSecret,
            redirectURI: Self.oauthRedirectURI
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

        if let downloadedProfile = try? await fetchProfile(for: account) {
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
            if handleRefreshFailureForReauthenticationIfNeeded(error, accountID: account.id) {
                return
            }

            globalErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func fetchTimeline(
        kind: TimelineKind,
        maxId: String?,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
        requestNonce: String? = nil
    ) async throws -> LinkableResult<Status> {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        var queryItems = kind.queryItems
        if let maxId = maxId?.nilIfEmpty {
            queryItems.append(URLQueryItem(name: "maxId", value: maxId))
        }
        if let requestNonce = requestNonce?.nilIfEmpty {
            queryItems.append(URLQueryItem(name: "_t", value: requestNonce))
        }

        let result: LinkableResult<Status> = try await authorizedRequest(
            account: account,
            path: kind.path,
            queryItems: queryItems,
            cachePolicy: cachePolicy
        )

        return result
    }

    func fetchTrendingStatuses(
        period: TrendingPeriodSelection,
        maxId: String?,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
        requestNonce: String? = nil
    ) async throws -> LinkableResult<Status> {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        var queryItems = [
            URLQueryItem(name: "limit", value: "40"),
            URLQueryItem(name: "period", value: period.rawValue)
        ]

        if let maxId = maxId?.nilIfEmpty {
            queryItems.append(URLQueryItem(name: "maxId", value: maxId))
        }
        if let requestNonce = requestNonce?.nilIfEmpty {
            queryItems.append(URLQueryItem(name: "_t", value: requestNonce))
        }

        let result: LinkableResult<Status> = try await authorizedRequest(
            account: account,
            path: "/api/v1/trending/statuses",
            queryItems: queryItems,
            cachePolicy: cachePolicy
        )

        return result
    }

    func fetchFeaturedUsers(maxId: String?, limit: Int = 40) async throws -> LinkableResult<User> {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        var queryItems = [URLQueryItem(name: "limit", value: "\(max(limit, 1))")]
        if let maxId = maxId?.nilIfEmpty {
            queryItems.append(URLQueryItem(name: "maxId", value: maxId))
        }

        let result: LinkableResult<User> = try await authorizedRequest(
            account: account,
            path: "/api/v1/timelines/featured-users",
            queryItems: queryItems
        )

        return result
    }

    func fetchTrendingUsers(
        period: TrendingPeriodSelection,
        maxId: String?,
        limit: Int = 40
    ) async throws -> LinkableResult<User> {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        var queryItems = [
            URLQueryItem(name: "limit", value: "\(max(limit, 1))"),
            URLQueryItem(name: "period", value: period.rawValue)
        ]

        if let maxId = maxId?.nilIfEmpty {
            queryItems.append(URLQueryItem(name: "maxId", value: maxId))
        }

        let result: LinkableResult<User> = try await authorizedRequest(
            account: account,
            path: "/api/v1/trending/users",
            queryItems: queryItems
        )

        return result
    }

    func fetchTrendingHashtags(
        period: TrendingPeriodSelection,
        maxId: String?,
        limit: Int = 40
    ) async throws -> LinkableResult<Hashtag> {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        var queryItems = [
            URLQueryItem(name: "limit", value: "\(max(limit, 1))"),
            URLQueryItem(name: "period", value: period.rawValue)
        ]

        if let maxId = maxId?.nilIfEmpty {
            queryItems.append(URLQueryItem(name: "maxId", value: maxId))
        }

        let result: LinkableResult<Hashtag> = try await authorizedRequest(
            account: account,
            path: "/api/v1/trending/hashtags",
            queryItems: queryItems
        )

        return result
    }

    func fetchNotifications(maxId: String?) async throws -> LinkableResult<AppNotification> {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        var queryItems = [URLQueryItem(name: "limit", value: "40")]
        if let maxId = maxId?.nilIfEmpty {
            queryItems.append(URLQueryItem(name: "maxId", value: maxId))
        }

        let result: LinkableResult<AppNotification> = try await authorizedRequest(
            account: account,
            path: "/api/v1/notifications",
            queryItems: queryItems
        )

        return result
    }

    func fetchNotificationsCount() async throws -> NotificationsCount {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        return try await authorizedRequest(
            account: account,
            path: "/api/v1/notifications/count",
            queryItems: []
        )
    }

    func updateNotificationMarker(notificationId: String) async throws {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let encodedNotificationId = notificationId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? notificationId

        try await authorizedRequestNoContent(
            account: account,
            path: "/api/v1/notifications/marker/\(encodedNotificationId)",
            method: "POST",
            queryItems: []
        )
    }

    func refreshUnreadNotificationsCount() async {
        guard activeAccount != nil else {
            unreadNotificationsCount = 0
            return
        }

        do {
            let count = try await fetchNotificationsCount()
            self.unreadNotificationsCount = max(0, count.amount ?? 0)
        } catch {
            // Keep the current badge state when counter refresh fails.
        }
    }

    func showErrorToast(_ message: String) {
        guard let presentableMessage = message.toastPresentableMessage else {
            return
        }

        toastDismissTask?.cancel()
        toastMessage = presentableMessage

        toastDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else {
                return
            }

            self?.toastMessage = nil
        }
    }

    func search(query: String, type: String) async throws -> SearchResult {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let queryWithoutHashtags = query.replacingOccurrences(of: "#", with: "")
        let queryItems = [
            URLQueryItem(name: "query", value: queryWithoutHashtags),
            URLQueryItem(name: "type", value: type)
        ]

        return try await authorizedRequest(
            account: account,
            path: "/api/v1/search",
            queryItems: queryItems
        )
    }

    func updateStatusInteraction(statusId: String, action: StatusInteractionAction) async throws -> Status {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        var headers: [String: String] = [:]
        var body: Data?

        if action == .reblog {
            headers["Content-Type"] = "application/json"
            body = try JSONEncoder().encode(ReblogRequest(visibility: "public"))
        }

        return try await authorizedRequest(
            account: account,
            path: "/api/v1/statuses/\(statusId)/\(action.pathSuffix)",
            method: "POST",
            queryItems: [],
            additionalHeaders: headers,
            body: body
        )
    }

    func fetchStatus(statusId: String) async throws -> Status {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let encodedStatusId = statusId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? statusId

        return try await authorizedRequest(
            account: account,
            path: "/api/v1/statuses/\(encodedStatusId)",
            queryItems: []
        )
    }

    func fetchStatusRebloggedBy(statusId: String, maxId: String?, limit: Int = 40) async throws -> LinkableResult<User> {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let encodedStatusId = statusId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? statusId

        var queryItems = [URLQueryItem(name: "limit", value: "\(max(limit, 1))")]
        if let maxId = maxId?.nilIfEmpty {
            queryItems.append(URLQueryItem(name: "maxId", value: maxId))
        }

        return try await authorizedRequest(
            account: account,
            path: "/api/v1/statuses/\(encodedStatusId)/reblogged",
            queryItems: queryItems
        )
    }

    func fetchStatusFavouritedBy(statusId: String, maxId: String?, limit: Int = 40) async throws -> LinkableResult<User> {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let encodedStatusId = statusId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? statusId

        var queryItems = [URLQueryItem(name: "limit", value: "\(max(limit, 1))")]
        if let maxId = maxId?.nilIfEmpty {
            queryItems.append(URLQueryItem(name: "maxId", value: maxId))
        }

        return try await authorizedRequest(
            account: account,
            path: "/api/v1/statuses/\(encodedStatusId)/favourited",
            queryItems: queryItems
        )
    }

    func deleteStatus(statusId: String) async throws {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let encodedStatusId = statusId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? statusId

        try await authorizedRequestNoContent(
            account: account,
            path: "/api/v1/statuses/\(encodedStatusId)",
            method: "DELETE",
            queryItems: []
        )
    }

    func applyContentWarning(statusId: String, contentWarning: String) async throws {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let encodedStatusId = statusId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? statusId
        let payload = ContentWarningRequestBody(contentWarning: contentWarning)

        try await authorizedRequestNoContent(
            account: account,
            path: "/api/v1/statuses/\(encodedStatusId)/apply-content-warning",
            method: "POST",
            queryItems: [],
            additionalHeaders: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(payload)
        )
    }

    func fetchStatusContext(statusId: String) async throws -> StatusContext {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let encodedStatusId = statusId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? statusId

        return try await authorizedRequest(
            account: account,
            path: "/api/v1/statuses/\(encodedStatusId)/context",
            queryItems: []
        )
    }

    func createComment(note: String, replyToStatusId: String) async throws -> Status {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let request = NewStatusRequest(note: note, replyToStatusId: replyToStatusId)

        return try await authorizedRequest(
            account: account,
            path: "/api/v1/statuses",
            method: "POST",
            queryItems: [],
            additionalHeaders: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(request)
        )
    }

    func createStatus(request: StatusComposeRequest) async throws -> Status {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        return try await authorizedRequest(
            account: account,
            path: "/api/v1/statuses",
            method: "POST",
            queryItems: [],
            additionalHeaders: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(request)
        )
    }

    func updateStatus(statusId: String, request: StatusComposeRequest) async throws -> Status {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let encodedStatusId = statusId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? statusId

        return try await authorizedRequest(
            account: account,
            path: "/api/v1/statuses/\(encodedStatusId)",
            method: "PUT",
            queryItems: [],
            additionalHeaders: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(request)
        )
    }

    func uploadAttachment(imageData: Data, fileName: String, mimeType: String) async throws -> UploadedAttachment {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        let requestBody = MultipartFormDataBuilder.buildSingleFileBody(
            boundary: boundary,
            fieldName: "file",
            fileName: fileName,
            mimeType: mimeType,
            fileData: imageData
        )

        return try await authorizedRequest(
            account: account,
            path: "/api/v1/attachments",
            method: "POST",
            queryItems: [],
            additionalHeaders: ["Content-Type": "multipart/form-data; boundary=\(boundary)"],
            body: requestBody
        )
    }

    func updateAttachment(attachmentId: String, request: AttachmentUpdateRequest) async throws {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let encodedAttachmentId = attachmentId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? attachmentId

        try await authorizedRequestNoContent(
            account: account,
            path: "/api/v1/attachments/\(encodedAttachmentId)",
            method: "PUT",
            queryItems: [],
            additionalHeaders: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(request)
        )
    }

    func deleteAttachment(attachmentId: String) async throws {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let encodedAttachmentId = attachmentId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? attachmentId

        try await authorizedRequestNoContent(
            account: account,
            path: "/api/v1/attachments/\(encodedAttachmentId)",
            method: "DELETE",
            queryItems: []
        )
    }

    func describeAttachment(attachmentId: String) async throws -> String? {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let encodedAttachmentId = attachmentId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? attachmentId

        let response: AttachmentDescriptionResult = try await authorizedRequest(
            account: account,
            path: "/api/v1/attachments/\(encodedAttachmentId)/describe",
            queryItems: []
        )

        return response.description?.nilIfEmpty
    }

    func fetchPublicSettings() async throws -> PublicSettings {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        return try await authorizedRequest(
            account: account,
            path: "/api/v1/settings/public",
            queryItems: [],
            showToastOnError: false
        )
    }

    func fetchEmailVerified() async throws -> Bool {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let response: BooleanResponse = try await authorizedRequest(
            account: account,
            path: "/api/v1/account/email/verified",
            queryItems: [],
            showToastOnError: false
        )

        return response.result
    }

    func resendEmailConfirmation() async throws {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let redirectBaseUrl = try URLSanitizer.sanitizeBaseURL(account.instanceURL).absoluteString
        let payload = ResendEmailConfirmationRequest(redirectBaseUrl: redirectBaseUrl)

        try await authorizedRequestNoContent(
            account: account,
            path: "/api/v1/account/email/resend",
            method: "POST",
            queryItems: [],
            additionalHeaders: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(payload),
            showToastOnError: false
        )
    }

    func fetchUserSetting(key: String) async throws -> UserSetting? {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? key

        do {
            let setting: UserSetting = try await authorizedRequest(
                account: account,
                path: "/api/v1/user-settings/\(encodedKey)",
                queryItems: [],
                showToastOnError: false
            )
            return setting
        } catch let APIError.http(statusCode, _) where statusCode == 404 {
            return nil
        }
    }

    func setUserSetting(key: String, value: String) async throws -> UserSetting {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let payload = UserSetting(key: key, value: value)
        return try await authorizedRequest(
            account: account,
            path: "/api/v1/user-settings",
            method: "PUT",
            queryItems: [],
            additionalHeaders: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(payload)
        )
    }

    func fetchCategories() async throws -> [Category] {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        return try await authorizedRequest(
            account: account,
            path: "/api/v1/categories/all",
            queryItems: [URLQueryItem(name: "onlyUsed", value: "false")]
        )
    }

    func fetchLicenses() async throws -> [License] {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let result: PagedResult<License> = try await authorizedRequest(
            account: account,
            path: "/api/v1/licenses",
            queryItems: [
                URLQueryItem(name: "page", value: "1"),
                URLQueryItem(name: "size", value: "100")
            ]
        )

        return result.data ?? []
    }

    func fetchCountries() async throws -> [Country] {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        return try await authorizedRequest(
            account: account,
            path: "/api/v1/countries",
            queryItems: []
        )
    }

    func searchLocations(countryCode: String, query: String) async throws -> [Location] {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return []
        }

        return try await authorizedRequest(
            account: account,
            path: "/api/v1/locations",
            queryItems: [
                URLQueryItem(name: "code", value: countryCode),
                URLQueryItem(name: "query", value: trimmedQuery)
            ]
        )
    }

    func fetchActiveProfile() async throws -> User {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let profile = try await fetchProfile(for: account)
        syncActiveAccount(using: profile)
        return profile
    }

    func fetchUserProfile(userName: String) async throws -> User {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let cleanedName = userName.trimmingPrefix("@")
        let encodedName = cleanedName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleanedName

        return try await authorizedRequest(
            account: account,
            path: "/api/v1/users/\(encodedName)",
            queryItems: []
        )
    }

    func fetchRelationship(userId: String) async throws -> Relationship {
        let relationships = try await fetchRelationships(userIds: [userId])
        return relationships.first ?? Relationship(userId: userId)
    }

    func fetchRelationships(userIds: [String]) async throws -> [Relationship] {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let cleanedIds = Array(Set(userIds.compactMap { $0.nilIfEmpty }))
        guard !cleanedIds.isEmpty else {
            return []
        }

        let queryItems = cleanedIds.map { URLQueryItem(name: "id[]", value: $0) }

        return try await authorizedRequest(
            account: account,
            path: "/api/v1/relationships",
            queryItems: queryItems
        )
    }

    func follow(userName: String) async throws -> Relationship {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let cleanedName = userName.trimmingPrefix("@")
        let encodedName = cleanedName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleanedName

        return try await authorizedRequest(
            account: account,
            path: "/api/v1/users/@\(encodedName)/follow",
            method: "POST",
            queryItems: []
        )
    }

    func unfollow(userName: String) async throws -> Relationship {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let cleanedName = userName.trimmingPrefix("@")
        let encodedName = cleanedName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleanedName

        return try await authorizedRequest(
            account: account,
            path: "/api/v1/users/@\(encodedName)/unfollow",
            method: "POST",
            queryItems: []
        )
    }

    func mute(
        userName: String,
        muteStatuses: Bool,
        muteReblogs: Bool,
        muteNotifications: Bool,
        muteEnd: Date?
    ) async throws -> Relationship {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let cleanedName = userName.trimmingPrefix("@")
        let encodedName = cleanedName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleanedName

        let payload = UserMuteRequestBody(
            muteStatuses: muteStatuses,
            muteReblogs: muteReblogs,
            muteNotifications: muteNotifications,
            muteEnd: muteEnd.map { Self.iso8601Formatter.string(from: $0) }
        )

        return try await authorizedRequest(
            account: account,
            path: "/api/v1/users/@\(encodedName)/mute",
            method: "POST",
            queryItems: [],
            additionalHeaders: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(payload)
        )
    }

    func unmute(userName: String) async throws -> Relationship {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let cleanedName = userName.trimmingPrefix("@")
        let encodedName = cleanedName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleanedName

        return try await authorizedRequest(
            account: account,
            path: "/api/v1/users/@\(encodedName)/unmute",
            method: "POST",
            queryItems: []
        )
    }

    func featureUser(userName: String) async throws -> User {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let cleanedName = userName.trimmingPrefix("@")
        let encodedName = cleanedName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleanedName

        return try await authorizedRequest(
            account: account,
            path: "/api/v1/users/@\(encodedName)/feature",
            method: "POST",
            queryItems: []
        )
    }

    func unfeatureUser(userName: String) async throws -> User {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let cleanedName = userName.trimmingPrefix("@")
        let encodedName = cleanedName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleanedName

        return try await authorizedRequest(
            account: account,
            path: "/api/v1/users/@\(encodedName)/unfeature",
            method: "POST",
            queryItems: []
        )
    }

    func blockDomain(domain: String, reason: String?) async throws {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let payload = UserBlockedDomainRequest(
            domain: domain,
            reason: reason?.nilIfEmpty
        )

        try await authorizedRequestNoContent(
            account: account,
            path: "/api/v1/user-blocked-domains",
            method: "POST",
            queryItems: [],
            additionalHeaders: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(payload)
        )
    }

    func approveFollowRequest(userId: String) async throws -> Relationship {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let encodedId = userId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? userId

        return try await authorizedRequest(
            account: account,
            path: "/api/v1/follow-requests/\(encodedId)/approve",
            method: "POST",
            queryItems: []
        )
    }

    func rejectFollowRequest(userId: String) async throws -> Relationship {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let encodedId = userId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? userId

        return try await authorizedRequest(
            account: account,
            path: "/api/v1/follow-requests/\(encodedId)/reject",
            method: "POST",
            queryItems: []
        )
    }

    func fetchUserStatuses(userName: String, maxId: String?, limit: Int = 40) async throws -> LinkableResult<Status> {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let cleanedName = userName.trimmingPrefix("@")
        let encodedName = cleanedName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleanedName

        var queryItems = [URLQueryItem(name: "limit", value: "\(max(limit, 1))")]
        if let maxId = maxId?.nilIfEmpty {
            queryItems.append(URLQueryItem(name: "maxId", value: maxId))
        }

        return try await authorizedRequest(
            account: account,
            path: "/api/v1/users/\(encodedName)/statuses",
            queryItems: queryItems
        )
    }

    func fetchHashtagStatuses(
        hashtag: String,
        maxId: String?,
        limit: Int = 40,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
        requestNonce: String? = nil
    ) async throws -> LinkableResult<Status> {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let cleanedName = hashtag.trimmingPrefix("#")
        let encodedName = cleanedName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleanedName

        var queryItems = [URLQueryItem(name: "limit", value: "\(max(limit, 1))")]
        if let maxId = maxId?.nilIfEmpty {
            queryItems.append(URLQueryItem(name: "maxId", value: maxId))
        }
        if let requestNonce = requestNonce?.nilIfEmpty {
            queryItems.append(URLQueryItem(name: "_t", value: requestNonce))
        }

        return try await authorizedRequest(
            account: account,
            path: "/api/v1/timelines/hashtag/\(encodedName)",
            queryItems: queryItems,
            cachePolicy: cachePolicy
        )
    }

    func fetchCategoryStatuses(
        category: String,
        maxId: String?,
        limit: Int = 40,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
        requestNonce: String? = nil
    ) async throws -> LinkableResult<Status> {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let cleanedName = category
            .trimmingPrefix("#")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var queryItems = [URLQueryItem(name: "limit", value: "\(max(limit, 1))")]
        if let maxId = maxId?.nilIfEmpty {
            queryItems.append(URLQueryItem(name: "maxId", value: maxId))
        }
        if let requestNonce = requestNonce?.nilIfEmpty {
            queryItems.append(URLQueryItem(name: "_t", value: requestNonce))
        }

        return try await authorizedRequest(
            account: account,
            path: "/api/v1/timelines/category/\(cleanedName)",
            queryItems: queryItems,
            cachePolicy: cachePolicy
        )
    }

    func fetchUserFollowing(userName: String, maxId: String?, limit: Int = 40) async throws -> LinkableResult<User> {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let cleanedName = userName.trimmingPrefix("@")
        let encodedName = cleanedName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleanedName

        var queryItems = [URLQueryItem(name: "limit", value: "\(max(limit, 1))")]
        if let maxId = maxId?.nilIfEmpty {
            queryItems.append(URLQueryItem(name: "maxId", value: maxId))
        }

        let result: LinkableResult<User> = try await authorizedRequest(
            account: account,
            path: "/api/v1/users/\(encodedName)/following",
            queryItems: queryItems
        )

        return result
    }

    func fetchUserFollowers(userName: String, maxId: String?, limit: Int = 40) async throws -> LinkableResult<User> {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let cleanedName = userName.trimmingPrefix("@")
        let encodedName = cleanedName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleanedName

        var queryItems = [URLQueryItem(name: "limit", value: "\(max(limit, 1))")]
        if let maxId = maxId?.nilIfEmpty {
            queryItems.append(URLQueryItem(name: "maxId", value: maxId))
        }

        let result: LinkableResult<User> = try await authorizedRequest(
            account: account,
            path: "/api/v1/users/\(encodedName)/followers",
            queryItems: queryItems
        )

        return result
    }

    func fetchLatestFollowers(userName: String, limit: Int = 10) async throws -> [User] {
        let result = try await fetchUserFollowers(userName: userName, maxId: nil, limit: limit)
        return result.data
    }

    func updateActiveProfile(request profileUpdateRequest: UpdateProfileRequest) async throws -> User {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let cleanedName = account.userName.trimmingPrefix("@")
        let encodedName = cleanedName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleanedName

        let updatedUser: User = try await authorizedRequest(
            account: account,
            path: "/api/v1/users/@\(encodedName)",
            method: "PUT",
            queryItems: [],
            additionalHeaders: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(profileUpdateRequest)
        )

        syncActiveAccount(using: updatedUser)

        return updatedUser
    }

    func uploadActiveAvatar(imageData: Data, fileName: String = "avatar.jpg", mimeType: String = "image/jpeg") async throws -> User {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let cleanedName = account.userName.trimmingPrefix("@")
        let encodedName = cleanedName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleanedName

        let boundary = "Boundary-\(UUID().uuidString)"
        let requestBody = MultipartFormDataBuilder.buildSingleFileBody(
            boundary: boundary,
            fieldName: "file",
            fileName: fileName,
            mimeType: mimeType,
            fileData: imageData
        )

        try await authorizedRequestNoContent(
            account: account,
            path: "/api/v1/avatars/@\(encodedName)",
            method: "POST",
            queryItems: [],
            additionalHeaders: ["Content-Type": "multipart/form-data; boundary=\(boundary)"],
            body: requestBody
        )

        return try await fetchActiveProfile()
    }

    func deleteActiveAvatar() async throws -> User {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let cleanedName = account.userName.trimmingPrefix("@")
        let encodedName = cleanedName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleanedName

        try await authorizedRequestNoContent(
            account: account,
            path: "/api/v1/avatars/@\(encodedName)",
            method: "DELETE",
            queryItems: []
        )

        return try await fetchActiveProfile()
    }

    func uploadActiveHeader(imageData: Data, fileName: String = "header.jpg", mimeType: String = "image/jpeg") async throws -> User {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let cleanedName = account.userName.trimmingPrefix("@")
        let encodedName = cleanedName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleanedName

        let boundary = "Boundary-\(UUID().uuidString)"
        let requestBody = MultipartFormDataBuilder.buildSingleFileBody(
            boundary: boundary,
            fieldName: "file",
            fileName: fileName,
            mimeType: mimeType,
            fileData: imageData
        )

        try await authorizedRequestNoContent(
            account: account,
            path: "/api/v1/headers/@\(encodedName)",
            method: "POST",
            queryItems: [],
            additionalHeaders: ["Content-Type": "multipart/form-data; boundary=\(boundary)"],
            body: requestBody
        )

        return try await fetchActiveProfile()
    }

    func deleteActiveHeader() async throws -> User {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let cleanedName = account.userName.trimmingPrefix("@")
        let encodedName = cleanedName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleanedName

        try await authorizedRequestNoContent(
            account: account,
            path: "/api/v1/headers/@\(encodedName)",
            method: "DELETE",
            queryItems: []
        )

        return try await fetchActiveProfile()
    }

    func deleteActiveAccount() async throws {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let cleanedName = account.userName.trimmingPrefix("@")
        let encodedName = cleanedName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleanedName

        try await authorizedRequestNoContent(
            account: account,
            path: "/api/v1/users/@\(encodedName)",
            method: "DELETE",
            queryItems: []
        )
    }

    func fetchFavourites(maxId: String?, limit: Int = 40) async throws -> LinkableResult<Status> {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        var queryItems = [URLQueryItem(name: "limit", value: "\(max(limit, 1))")]
        if let maxId = maxId?.nilIfEmpty {
            queryItems.append(URLQueryItem(name: "maxId", value: maxId))
        }

        return try await authorizedRequest(
            account: account,
            path: "/api/v1/favourites",
            queryItems: queryItems
        )
    }

    func fetchBookmarks(maxId: String?, limit: Int = 40) async throws -> LinkableResult<Status> {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        var queryItems = [URLQueryItem(name: "limit", value: "\(max(limit, 1))")]
        if let maxId = maxId?.nilIfEmpty {
            queryItems.append(URLQueryItem(name: "maxId", value: maxId))
        }

        return try await authorizedRequest(
            account: account,
            path: "/api/v1/bookmarks",
            queryItems: queryItems
        )
    }

    func activeBusinessCardExists() async throws -> Bool {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        do {
            let _: BusinessCard = try await authorizedRequest(
                account: account,
                path: "/api/v1/business-cards",
                queryItems: [],
                showToastOnError: false
            )
            return true
        } catch let APIError.http(statusCode, _) where statusCode == 404 {
            return false
        }
    }

    func fetchSharedBusinessCards(page: Int, size: Int) async throws -> PagedResult<SharedBusinessCard> {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        return try await authorizedRequest(
            account: account,
            path: "/api/v1/shared-business-cards",
            queryItems: [
                URLQueryItem(name: "page", value: "\(max(page, 1))"),
                URLQueryItem(name: "size", value: "\(max(size, 1))")
            ]
        )
    }

    func fetchSharedBusinessCard(id: String) async throws -> SharedBusinessCard {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let encodedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id

        return try await authorizedRequest(
            account: account,
            path: "/api/v1/shared-business-cards/\(encodedId)",
            queryItems: []
        )
    }

    func sendSharedBusinessCardMessage(id: String, message: String) async throws {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let encodedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let payload = SharedBusinessCardMessageRequest(
            message: message,
            addedByUser: true
        )

        try await authorizedRequestNoContent(
            account: account,
            path: "/api/v1/shared-business-cards/\(encodedId)/message",
            method: "POST",
            queryItems: [],
            additionalHeaders: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(payload)
        )
    }

    func createSharedBusinessCard(
        title: String,
        note: String?,
        thirdPartyName: String?,
        thirdPartyEmail: String?
    ) async throws -> SharedBusinessCard {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let payload = SharedBusinessCardRequest(
            title: title,
            note: note?.nilIfEmpty,
            thirdPartyName: thirdPartyName?.nilIfEmpty,
            thirdPartyEmail: thirdPartyEmail?.nilIfEmpty
        )

        return try await authorizedRequest(
            account: account,
            path: "/api/v1/shared-business-cards",
            method: "POST",
            queryItems: [],
            additionalHeaders: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(payload)
        )
    }

    func updateSharedBusinessCard(
        id: String,
        title: String,
        note: String?,
        thirdPartyName: String?,
        thirdPartyEmail: String?
    ) async throws -> SharedBusinessCard {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let encodedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let payload = SharedBusinessCardRequest(
            title: title,
            note: note?.nilIfEmpty,
            thirdPartyName: thirdPartyName?.nilIfEmpty,
            thirdPartyEmail: thirdPartyEmail?.nilIfEmpty
        )

        return try await authorizedRequest(
            account: account,
            path: "/api/v1/shared-business-cards/\(encodedId)",
            method: "PUT",
            queryItems: [],
            additionalHeaders: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(payload)
        )
    }

    func deleteSharedBusinessCard(id: String) async throws {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let encodedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id

        try await authorizedRequestNoContent(
            account: account,
            path: "/api/v1/shared-business-cards/\(encodedId)",
            method: "DELETE",
            queryItems: []
        )
    }

    func revokeSharedBusinessCard(id: String) async throws {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let encodedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id

        try await authorizedRequestNoContent(
            account: account,
            path: "/api/v1/shared-business-cards/\(encodedId)/revoke",
            method: "POST",
            queryItems: []
        )
    }

    func unrevokeSharedBusinessCard(id: String) async throws {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let encodedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id

        try await authorizedRequestNoContent(
            account: account,
            path: "/api/v1/shared-business-cards/\(encodedId)/unrevoke",
            method: "POST",
            queryItems: []
        )
    }

    func fetchInstanceDetails() async throws -> InstanceDetails {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        return try await authorizedRequest(
            account: account,
            path: "/api/v1/instance",
            queryItems: []
        )
    }

    func fetchInstanceRules() async throws -> [InstanceRule] {
        let instance = try await fetchInstanceDetails()
        return (instance.rules ?? []).sorted { $0.id < $1.id }
    }

    func createReport(
        reportedUserId: String,
        statusId: String?,
        comment: String?,
        category: String?,
        ruleIds: [Int],
        forward: Bool = false
    ) async throws {
        guard let account = activeAccount else {
            throw APIError.noActiveAccount
        }

        let payload = ReportRequestBody(
            reportedUserId: reportedUserId,
            statusId: statusId?.nilIfEmpty,
            comment: comment?.nilIfEmpty,
            forward: forward,
            category: category?.nilIfEmpty,
            ruleIds: ruleIds.isEmpty ? nil : ruleIds
        )

        try await authorizedRequestNoContent(
            account: account,
            path: "/api/v1/reports",
            method: "POST",
            queryItems: [],
            additionalHeaders: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(payload)
        )
    }

    private func fetchProfile(for account: StoredAccount) async throws -> User {
        let cleanedName = account.userName.trimmingPrefix("@")
        let encodedName = cleanedName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleanedName

        return try await authorizedRequest(
            account: account,
            path: "/api/v1/users/\(encodedName)",
            queryItems: []
        )
    }

    private func authorizedRequest<T: Decodable>(
        account: StoredAccount,
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem],
        additionalHeaders: [String: String] = [:],
        body: Data? = nil,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
        showToastOnError: Bool = true
    ) async throws -> T {
        var headers = ["Authorization": "Bearer \(account.accessToken)"]
        additionalHeaders.forEach { headers[$0.key] = $0.value }

        do {
            return try await APIClient.requestJSON(
                baseURL: URLSanitizer.sanitizeBaseURL(account.instanceURL),
                path: path,
                method: method,
                queryItems: queryItems,
                headers: headers,
                body: body,
                cachePolicy: cachePolicy
            )
        } catch let APIError.http(statusCode, _) where statusCode == 401 {
            guard let refreshed = try await refresh(account: account) else {
                throw APIError.http(statusCode: 401, body: "Access token expired and no refresh token available.")
            }

            var refreshedHeaders = ["Authorization": "Bearer \(refreshed.accessToken)"]
            additionalHeaders.forEach { refreshedHeaders[$0.key] = $0.value }

            do {
                return try await APIClient.requestJSON(
                    baseURL: URLSanitizer.sanitizeBaseURL(refreshed.instanceURL),
                    path: path,
                    method: method,
                    queryItems: queryItems,
                    headers: refreshedHeaders,
                    body: body,
                    cachePolicy: cachePolicy
                )
            } catch {
                if showToastOnError {
                    showErrorToast((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
                }
                throw error
            }
        } catch {
            if showToastOnError {
                showErrorToast((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            }
            throw error
        }
    }

    private func authorizedRequestNoContent(
        account: StoredAccount,
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem],
        additionalHeaders: [String: String] = [:],
        body: Data? = nil,
        showToastOnError: Bool = true
    ) async throws {
        var headers = ["Authorization": "Bearer \(account.accessToken)"]
        additionalHeaders.forEach { headers[$0.key] = $0.value }

        do {
            try await APIClient.requestNoContent(
                baseURL: URLSanitizer.sanitizeBaseURL(account.instanceURL),
                path: path,
                method: method,
                queryItems: queryItems,
                headers: headers,
                body: body
            )
        } catch let APIError.http(statusCode, _) where statusCode == 401 {
            guard let refreshed = try await refresh(account: account) else {
                throw APIError.http(statusCode: 401, body: "Access token expired and no refresh token available.")
            }

            var refreshedHeaders = ["Authorization": "Bearer \(refreshed.accessToken)"]
            additionalHeaders.forEach { refreshedHeaders[$0.key] = $0.value }

            do {
                try await APIClient.requestNoContent(
                    baseURL: URLSanitizer.sanitizeBaseURL(refreshed.instanceURL),
                    path: path,
                    method: method,
                    queryItems: queryItems,
                    headers: refreshedHeaders,
                    body: body
                )
            } catch {
                if showToastOnError {
                    showErrorToast((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
                }
                throw error
            }
        } catch {
            if showToastOnError {
                showErrorToast((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            }
            throw error
        }
    }

    private func refresh(account: StoredAccount) async throws -> StoredAccount? {
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
            if handleRefreshFailureForReauthenticationIfNeeded(error, accountID: account.id) {
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

    @discardableResult
    private func handleRefreshFailureForReauthenticationIfNeeded(_ error: Error, accountID: UUID) -> Bool {
        guard shouldForceReauthentication(for: error) else {
            return false
        }

        invalidateSessionAndRequireReauthentication(for: accountID)
        showErrorToast("Session expired. Sign in again.")
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
            activeAccountID = nil
            unreadNotificationsCount = 0
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
            globalErrorMessage = "Cannot encode accounts."
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

    static let oauthRedirectURI = "vernissage-mobile://oauth-callback"
    static let oauthScope = "read write profile"
}
