//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

enum ProfileContentTab: String, CaseIterable, Identifiable {
    case photos = "Photos"
    case following = "Following"
    case followers = "Followers"

    var id: String { rawValue }
}
