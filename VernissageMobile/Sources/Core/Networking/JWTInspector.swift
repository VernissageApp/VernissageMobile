//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

enum JWTInspector {
    static func decodeClaims(from token: String) -> JWTClaims? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else {
            return nil
        }

        let payload = String(parts[1])
        guard let data = Data(base64URLEncoded: payload),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let userName = object["userName"] as? String
        let name = object["name"] as? String
        let roles = object["roles"] as? [String]

        var expiration: Date?
        if let expNumber = object["exp"] as? Double {
            expiration = Date(timeIntervalSince1970: expNumber)
        } else if let expNumber = object["exp"] as? Int {
            expiration = Date(timeIntervalSince1970: TimeInterval(expNumber))
        }

        return JWTClaims(userName: userName, name: name, expiration: expiration, roles: roles)
    }
}
