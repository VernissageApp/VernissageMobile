//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct RegisterUserRequest: Encodable {
    let userName: String
    let email: String
    let password: String
    let name: String?
    let securityToken: String?
    let inviteToken: String?
    let redirectBaseUrl: String
    let agreement: Bool
    let locale: String
    let reason: String?
}
