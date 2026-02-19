//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

enum StatusInteractionAction {
    case reblog
    case unreblog
    case favourite
    case unfavourite
    case bookmark
    case unbookmark
    case feature
    case unfeature

    var pathSuffix: String {
        switch self {
        case .reblog: return "reblog"
        case .unreblog: return "unreblog"
        case .favourite: return "favourite"
        case .unfavourite: return "unfavourite"
        case .bookmark: return "bookmark"
        case .unbookmark: return "unbookmark"
        case .feature: return "feature"
        case .unfeature: return "unfeature"
        }
    }
}
