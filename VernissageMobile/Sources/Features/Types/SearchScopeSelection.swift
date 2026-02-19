//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

enum SearchScopeSelection: String, CaseIterable, Hashable {
    case users
    case hashtags
    case statuses

    var title: String {
        switch self {
        case .users:
            return "Users"
        case .hashtags:
            return "Hashtags"
        case .statuses:
            return "Statuses"
        }
    }

    static func fromQuery(_ query: String) -> SearchScopeSelection {
        if query.hasPrefix("#") {
            return .hashtags
        }

        if query.contains("@") {
            return .users
        }

        return .statuses
    }
}
