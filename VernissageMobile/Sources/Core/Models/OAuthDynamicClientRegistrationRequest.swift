//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct OAuthDynamicClientRegistrationRequest: Encodable {
    let redirectUris: [String]
    let tokenEndpointAuthMethod: String
    let grantTypes: [String]
    let responseTypes: [String]
    let clientName: String
    let scope: String
    let softwareId: String
    let softwareVersion: String

    enum CodingKeys: String, CodingKey {
        case redirectUris = "redirect_uris"
        case tokenEndpointAuthMethod = "token_endpoint_auth_method"
        case grantTypes = "grant_types"
        case responseTypes = "response_types"
        case clientName = "client_name"
        case scope
        case softwareId = "software_id"
        case softwareVersion = "software_version"
    }
}
