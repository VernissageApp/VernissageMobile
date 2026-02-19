//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

enum StatusVisibility: String, CaseIterable, Codable {
    case `public` = "public"
    case followers = "followers"
    case mentioned = "mentioned"

    var title: String {
        switch self {
        case .public:
            return "Everyone"
        case .followers:
            return "Followers only"
        case .mentioned:
            return "Mentioned people only"
        }
    }

    var icon: String {
        switch self {
        case .public:
            return "globe"
        case .followers:
            return "lock"
        case .mentioned:
            return "at"
        }
    }
}
