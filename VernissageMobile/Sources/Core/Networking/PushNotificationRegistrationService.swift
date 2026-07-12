//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation
import UserNotifications

@MainActor
struct PushNotificationRegistrationService {
    private let keyStore = PushSubscriptionKeyStore()

    func loadStoredSubscription(for account: StoredAccount) throws -> StoredPushSubscription? {
        try keyStore.load(subscriptionId: account.id.uuidString)
    }

    func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func requestAuthorizationForSettings() async throws -> Bool {
        try await requestAuthorizationIfNeeded()
    }

    func save(settings: PushNotificationSettings, using appState: AppState) async throws -> StoredPushSubscription {
        let account = try appState.requireActiveAccount()
        var storedSubscription = try loadStoredSubscription(for: account)

        if settings.notificationsEnabled {
            let authorized = try await requestAuthorizationIfNeeded()
            guard authorized else {
                throw PushNotificationError.permissionDenied
            }

            let deviceToken = try await requestDeviceToken()
            let keyMaterial = try storedSubscription?.keyMaterial ?? WebPushKeyMaterial.generate(subscriptionId: account.id.uuidString)
            let endpoint = try endpoint(deviceToken: deviceToken,
                                        subscriptionId: account.id.uuidString,
                                        environment: currentEnvironment)

            storedSubscription = StoredPushSubscription(
                subscriptionId: account.id.uuidString,
                serverSubscriptionId: storedSubscription?.serverSubscriptionId,
                endpoint: endpoint,
                deviceToken: deviceToken,
                environment: currentEnvironment,
                keyMaterial: keyMaterial,
                settings: settings
            )
        } else {
            guard let existingSubscription = storedSubscription else {
                let keyMaterial = try WebPushKeyMaterial.generate(subscriptionId: account.id.uuidString)
                let disabledSubscription = StoredPushSubscription(
                    subscriptionId: account.id.uuidString,
                    environment: currentEnvironment,
                    keyMaterial: keyMaterial,
                    settings: settings
                )
                try keyStore.save(disabledSubscription)
                return disabledSubscription
            }

            storedSubscription = StoredPushSubscription(
                subscriptionId: existingSubscription.subscriptionId,
                serverSubscriptionId: existingSubscription.serverSubscriptionId,
                endpoint: existingSubscription.endpoint,
                deviceToken: existingSubscription.deviceToken,
                environment: existingSubscription.environment,
                keyMaterial: existingSubscription.keyMaterial,
                settings: settings
            )
        }

        guard let storedSubscription else {
            throw PushNotificationError.missingStoredSubscription
        }

        try keyStore.save(storedSubscription)
        guard let endpoint = storedSubscription.endpoint else {
            return storedSubscription
        }

        let pushSubscription = PushSubscription(
            endpoint: endpoint,
            keyMaterial: storedSubscription.keyMaterial,
            settings: settings
        )

        let savedSubscription: PushSubscription
        if let serverSubscriptionId = storedSubscription.serverSubscriptionId {
            savedSubscription = try await appState.api.pushSubscriptions.updatePushSubscription(
                id: serverSubscriptionId,
                pushSubscription: pushSubscription
            )
        } else if let existingSubscription = try await matchingServerSubscription(
            subscriptionId: storedSubscription.subscriptionId,
            endpoint: endpoint,
            using: appState
        ), let existingId = existingSubscription.id {
            savedSubscription = try await appState.api.pushSubscriptions.updatePushSubscription(
                id: existingId,
                pushSubscription: pushSubscription
            )
        } else {
            savedSubscription = try await appState.api.pushSubscriptions.createPushSubscription(pushSubscription)
        }

        var updatedStoredSubscription = storedSubscription
        updatedStoredSubscription.serverSubscriptionId = savedSubscription.id
        try keyStore.save(updatedStoredSubscription)

        return updatedStoredSubscription
    }

    private var currentEnvironment: String {
        AppConstants.PushNotifications.productionEnvironment
    }

    private func requestAuthorizationIfNeeded() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        @unknown default:
            return false
        }
    }

    private func requestDeviceToken() async throws -> String {
        guard let appDelegate = PushNotificationAppDelegate.current else {
            throw PushNotificationError.deviceTokenUnavailable
        }

        let tokenData = try await appDelegate.registerForRemoteNotifications()
        return tokenData.map { String(format: "%02x", $0) }.joined()
    }

    private func endpoint(deviceToken: String, subscriptionId: String, environment: String) throws -> String {
        guard var components = URLComponents(string: AppConstants.PushNotifications.relayBaseURL) else {
            throw PushNotificationError.invalidRelayEndpoint
        }

        components.path = [
            AppConstants.PushNotifications.relayPath,
            environment,
            deviceToken,
            subscriptionId
        ].joined(separator: "/")

        guard let url = components.url else {
            throw PushNotificationError.invalidRelayEndpoint
        }

        return url.absoluteString
    }

    private func matchingServerSubscription(subscriptionId: String,
                                            endpoint: String,
                                            using appState: AppState) async throws -> PushSubscription? {
        let page = try await appState.api.pushSubscriptions.fetchPushSubscriptions()
        return page.data?.first { subscription in
            subscription.endpoint == endpoint || subscription.endpoint.hasSuffix("/\(subscriptionId)")
        }
    }
}
