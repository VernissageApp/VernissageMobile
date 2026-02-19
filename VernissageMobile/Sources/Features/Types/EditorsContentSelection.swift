//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

enum EditorsContentSelection: String, CaseIterable, Hashable {
    case photos
    case artists

    var title: String {
        switch self {
        case .photos:
            return "Photos"
        case .artists:
            return "Artists"
        }
    }

    var systemImage: String {
        switch self {
        case .photos:
            return "photo.on.rectangle.angled"
        case .artists:
            return "person.3"
        }
    }

    var subtitle: String {
        switch self {
        case .photos:
            return "A collection of photos that have been featured by curators on this server."
        case .artists:
            return "A collection of artists who have been featured by curators on this server."
        }
    }
}
