//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import CryptoKit
import Foundation

struct WebPushKeyMaterial: Codable, Equatable {
    let subscriptionId: String
    let privateKey: String
    let p256dh: String
    let auth: String
}

extension WebPushKeyMaterial {
    static func generate(subscriptionId: String) throws -> WebPushKeyMaterial {
        let privateKey = P256.KeyAgreement.PrivateKey()
        var authBytes = [UInt8](repeating: 0, count: 16)
        let status = SecRandomCopyBytes(kSecRandomDefault, authBytes.count, &authBytes)
        guard status == errSecSuccess else {
            throw PushNotificationError.authSecretGenerationFailed
        }

        return WebPushKeyMaterial(
            subscriptionId: subscriptionId,
            privateKey: privateKey.rawRepresentation.base64URLEncodedString(),
            p256dh: privateKey.publicKey.x963Representation.base64URLEncodedString(),
            auth: Data(authBytes).base64URLEncodedString()
        )
    }

    var privateKeyData: Data? {
        Data(base64URLEncoded: privateKey)
    }

    var publicKeyData: Data? {
        Data(base64URLEncoded: p256dh)
    }

    var authData: Data? {
        Data(base64URLEncoded: auth)
    }
}
