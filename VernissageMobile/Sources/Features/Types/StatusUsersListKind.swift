//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

enum StatusUsersListKind: String, Identifiable {
    case boostedBy
    case favouritedBy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .boostedBy:
            return "Boosted by"
        case .favouritedBy:
            return "Favourited by"
        }
    }

    var emptyTitle: String {
        switch self {
        case .boostedBy:
            return "No boosts yet"
        case .favouritedBy:
            return "No favourites yet"
        }
    }

    var emptyDescription: String {
        switch self {
        case .boostedBy:
            return "Users who boost this photo will appear here."
        case .favouritedBy:
            return "Users who favourite this photo will appear here."
        }
    }
}
