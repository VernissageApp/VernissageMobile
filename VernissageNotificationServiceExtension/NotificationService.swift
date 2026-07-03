//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation
import UserNotifications

final class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?
    private let keyStore = PushSubscriptionKeyStore()
    private let decryptor = WebPushDecryptor()

    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent

        guard let bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        do {
            try applyDecryptedContent(to: bestAttemptContent)
            contentHandler(bestAttemptContent)
        } catch {
            bestAttemptContent.title = AppConstants.PushNotifications.fallbackTitle
            bestAttemptContent.body = AppConstants.PushNotifications.fallbackBody
            contentHandler(bestAttemptContent)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler, let bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

    private func applyDecryptedContent(to content: UNMutableNotificationContent) throws {
        let userInfo = content.userInfo
        let payloadData = try JSONSerialization.data(withJSONObject: userInfo, options: [])
        let relayPayload = try JSONDecoder().decode(WebPushRelayPayload.self, from: payloadData)

        guard let subscriptionId = relayPayload.subscriptionId,
              let storedSubscription = try keyStore.load(subscriptionId: subscriptionId) else {
            throw PushNotificationError.missingStoredSubscription
        }

        let decryptedContent = try decryptor.decrypt(
            payload: relayPayload,
            keyMaterial: storedSubscription.keyMaterial
        )

        if let title = nonEmpty(decryptedContent.notification.title) {
            content.title = title
        }

        if let body = nonEmpty(decryptedContent.notification.body) {
            content.body = body
        }

        if let badgeCount = decryptedContent.notification.data?.badgeCount {
            content.badge = NSNumber(value: badgeCount)
        }
    }

    private func nonEmpty(_ value: String?) -> String? {
        let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmedValue, !trimmedValue.isEmpty else {
            return nil
        }

        return trimmedValue
    }
}
