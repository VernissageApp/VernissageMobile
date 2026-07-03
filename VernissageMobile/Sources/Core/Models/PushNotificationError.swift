//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

enum PushNotificationError: LocalizedError {
    case authSecretGenerationFailed
    case permissionDenied
    case deviceTokenUnavailable
    case invalidRelayEndpoint
    case missingStoredSubscription
    case invalidStoredKeyMaterial
    case unsupportedPayload
    case decryptionFailed

    var errorDescription: String? {
        switch self {
        case .authSecretGenerationFailed:
            "Cannot generate push notification encryption keys."
        case .permissionDenied:
            "Push notifications are disabled for Vernissage in system settings."
        case .deviceTokenUnavailable:
            "Cannot register this device for push notifications."
        case .invalidRelayEndpoint:
            "Push notification relay endpoint is invalid."
        case .missingStoredSubscription:
            "Cannot find local push notification keys."
        case .invalidStoredKeyMaterial:
            "Local push notification keys are invalid."
        case .unsupportedPayload:
            "Push notification payload is not supported."
        case .decryptionFailed:
            "Cannot decrypt push notification payload."
        }
    }
}
