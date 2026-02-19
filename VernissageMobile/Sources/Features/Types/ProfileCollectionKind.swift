//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

enum ProfileCollectionKind: Identifiable {
    case favourites
    case bookmarks

    var id: String {
        switch self {
        case .favourites:
            return "favourites"
        case .bookmarks:
            return "bookmarks"
        }
    }

    var title: String {
        switch self {
        case .favourites:
            return "Favourites"
        case .bookmarks:
            return "Bookmarks"
        }
    }

    var emptyTitle: String {
        switch self {
        case .favourites:
            return "No favourite photos"
        case .bookmarks:
            return "No bookmarked photos"
        }
    }

    var emptyDescription: String {
        switch self {
        case .favourites:
            return "Photos that you favourite will appear here."
        case .bookmarks:
            return "Photos that you bookmark will appear here."
        }
    }
}
