//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import CryptoKit
import Foundation

struct WebPushDecryptor {
    func decrypt(payload: WebPushRelayPayload, keyMaterial: WebPushKeyMaterial) throws -> WebPushNotificationContent {
        guard payload.encoding == "aes128gcm",
              let privateKeyData = keyMaterial.privateKeyData,
              let authData = keyMaterial.authData,
              let userPublicKeyData = keyMaterial.publicKeyData,
              let encryptedMessage = Data(base64URLEncoded: payload.message) else {
            throw PushNotificationError.unsupportedPayload
        }

        let parsedPayload = try parsePayload(encryptedMessage, relayPayload: payload)
        let decryptedData = try decryptAes128Gcm(
            encryptedData: parsedPayload.encryptedData,
            salt: parsedPayload.salt,
            serverPublicKeyData: parsedPayload.serverPublicKey,
            userPrivateKeyData: privateKeyData,
            userPublicKeyData: userPublicKeyData,
            authData: authData
        )

        do {
            return try JSONDecoder().decode(WebPushNotificationContent.self, from: decryptedData)
        } catch {
            throw PushNotificationError.decryptionFailed
        }
    }

    private func parsePayload(_ encryptedMessage: Data, relayPayload: WebPushRelayPayload) throws -> ParsedPayload {
        if encryptedMessage.count > 86 {
            let salt = encryptedMessage.prefix(16)
            let keyLength = Int(encryptedMessage[20])
            let keyStartIndex = 21
            let keyEndIndex = keyStartIndex + keyLength

            guard keyLength > 0, encryptedMessage.count > keyEndIndex else {
                throw PushNotificationError.unsupportedPayload
            }

            return ParsedPayload(
                salt: Data(salt),
                serverPublicKey: Data(encryptedMessage[keyStartIndex..<keyEndIndex]),
                encryptedData: Data(encryptedMessage[keyEndIndex...])
            )
        }

        guard let saltString = relayPayload.salt,
              let serverPublicKeyString = relayPayload.serverPublicKey,
              let salt = Data(base64URLEncoded: saltString),
              let serverPublicKey = Data(base64URLEncoded: serverPublicKeyString) else {
            throw PushNotificationError.unsupportedPayload
        }

        return ParsedPayload(
            salt: salt,
            serverPublicKey: serverPublicKey,
            encryptedData: encryptedMessage
        )
    }

    private func decryptAes128Gcm(encryptedData: Data,
                                  salt: Data,
                                  serverPublicKeyData: Data,
                                  userPrivateKeyData: Data,
                                  userPublicKeyData: Data,
                                  authData: Data) throws -> Data {
        guard encryptedData.count > 16 else {
            throw PushNotificationError.unsupportedPayload
        }

        do {
            let privateKey = try P256.KeyAgreement.PrivateKey(rawRepresentation: userPrivateKeyData)
            let serverPublicKey = try P256.KeyAgreement.PublicKey(x963Representation: serverPublicKeyData)
            let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: serverPublicKey)
            let sharedSecretData = sharedSecret.withUnsafeBytes { Data($0) }

            let pseudorandomKey = hkdfExtract(salt: authData, inputKeyMaterial: sharedSecretData)
            var keyInfo = Data("WebPush: info".utf8)
            keyInfo.append(0)
            keyInfo.append(userPublicKeyData)
            keyInfo.append(serverPublicKeyData)

            let inputKeyMaterial = hkdfExpand(pseudorandomKey: pseudorandomKey, info: keyInfo, outputByteCount: 32)
            let contentEncryptionKey = hkdfExpand(
                pseudorandomKey: hkdfExtract(salt: salt, inputKeyMaterial: inputKeyMaterial),
                info: Data("Content-Encoding: aes128gcm\u{0}".utf8),
                outputByteCount: 16
            )
            let nonce = hkdfExpand(
                pseudorandomKey: hkdfExtract(salt: salt, inputKeyMaterial: inputKeyMaterial),
                info: Data("Content-Encoding: nonce\u{0}".utf8),
                outputByteCount: 12
            )

            let ciphertext = encryptedData.dropLast(16)
            let tag = encryptedData.suffix(16)
            let sealedBox = try AES.GCM.SealedBox(
                nonce: AES.GCM.Nonce(data: nonce),
                ciphertext: ciphertext,
                tag: tag
            )

            let decrypted = try AES.GCM.open(sealedBox, using: SymmetricKey(data: contentEncryptionKey))
            return removeRecordDelimiter(from: decrypted)
        } catch {
            throw PushNotificationError.decryptionFailed
        }
    }

    private func hkdfExtract(salt: Data, inputKeyMaterial: Data) -> Data {
        let key = SymmetricKey(data: salt)
        let code = HMAC<SHA256>.authenticationCode(for: inputKeyMaterial, using: key)
        return Data(code)
    }

    private func hkdfExpand(pseudorandomKey: Data, info: Data, outputByteCount: Int) -> Data {
        var result = Data()
        var previousBlock = Data()
        var counter: UInt8 = 1

        while result.count < outputByteCount {
            var input = Data()
            input.append(previousBlock)
            input.append(info)
            input.append(counter)

            let key = SymmetricKey(data: pseudorandomKey)
            let code = HMAC<SHA256>.authenticationCode(for: input, using: key)
            previousBlock = Data(code)
            result.append(previousBlock)
            counter += 1
        }

        return Data(result.prefix(outputByteCount))
    }

    private func removeRecordDelimiter(from data: Data) -> Data {
        guard let lastByte = data.last,
              lastByte == 1 || lastByte == 2 else {
            return data
        }

        return Data(data.dropLast())
    }
}

private extension WebPushDecryptor {
    struct ParsedPayload {
        let salt: Data
        let serverPublicKey: Data
        let encryptedData: Data
    }
}
