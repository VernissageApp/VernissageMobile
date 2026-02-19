//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct JWTClaims {
    let userName: String?
    let name: String?
    let expiration: Date?
    let roles: [String]?
}
