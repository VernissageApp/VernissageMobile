//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

enum TrendingContentSelection: String, CaseIterable, Hashable {
    case photos
    case artists
    case tags

    var title: String {
        switch self {
        case .photos:
            return "Photos"
        case .artists:
            return "Artists"
        case .tags:
            return "Tags"
        }
    }

    var systemImage: String {
        switch self {
        case .photos:
            return "photo.on.rectangle.angled"
        case .artists:
            return "person.3"
        case .tags:
            return "number"
        }
    }

    var subtitle: String {
        switch self {
        case .photos:
            return "A collection of photos that received the most likes within a specified time frame."
        case .artists:
            return "A collection of artists who received the most likes on their photos within a specified time frame."
        case .tags:
            return "A collection of hashtags assigned to photos that received the most likes within a specified time frame."
        }
    }
}
