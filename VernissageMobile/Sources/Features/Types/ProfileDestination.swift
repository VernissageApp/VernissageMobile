//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

enum ProfileDestination: Identifiable {
    case favourites
    case bookmarks
    case instance
    case sharedBusinessCards

    var id: String {
        switch self {
        case .favourites:
            return "destination-favourites"
        case .bookmarks:
            return "destination-bookmarks"
        case .instance:
            return "destination-instance"
        case .sharedBusinessCards:
            return "destination-shared-business-cards"
        }
    }
}
