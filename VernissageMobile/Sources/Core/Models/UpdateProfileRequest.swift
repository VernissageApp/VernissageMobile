//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct UpdateProfileRequest: Encodable {
    let name: String?
    let bio: String?
    let locale: String?
    let manuallyApprovesFollowers: Bool?
    let includePublicPostsInSearchEngines: Bool?
    let includeProfilePageInSearchEngines: Bool?
    let fields: [UpdateProfileFlexiField]
}
