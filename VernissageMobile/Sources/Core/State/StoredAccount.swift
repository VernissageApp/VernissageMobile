//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct StoredAccount: Codable, Identifiable, Equatable {
    let id: UUID
    let instanceURL: String
    let clientID: String
    let clientSecret: String?

    var accessToken: String
    var refreshToken: String?
    var accessTokenExpiration: Date?

    let userName: String
    var displayName: String?
    var avatarURL: String?
}
