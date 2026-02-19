//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct OAuthTokenResponse: Decodable {
    let accessToken: String
    let tokenType: String
    let refreshToken: String?
    let expirationDate: Date?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        tokenType = try container.decodeIfPresent(String.self, forKey: .tokenType) ?? "bearer"
        refreshToken = try container.decodeIfPresent(String.self, forKey: .refreshToken)

        if let date = try? container.decode(Date.self, forKey: .expiresIn) {
            expirationDate = date
        } else if let seconds = try? container.decode(Double.self, forKey: .expiresIn) {
            expirationDate = Date(timeIntervalSince1970: seconds)
        } else if let stringValue = try? container.decode(String.self, forKey: .expiresIn),
                  let parsed = DateParser.parse(stringValue) {
            expirationDate = parsed
        } else {
            expirationDate = nil
        }
    }
}
