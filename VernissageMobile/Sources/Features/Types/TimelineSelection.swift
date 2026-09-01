//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

enum TimelineSelection: String, CaseIterable, Hashable {
    case privateHome
    case local
    case global

    var kind: TimelineKind {
        switch self {
        case .privateHome:
            return .privateHome
        case .local:
            return .local
        case .global:
            return .global
        }
    }

    var label: String {
        switch self {
        case .privateHome:
            return "Private"
        case .local:
            return "Local"
        case .global:
            return "Global"
        }
    }

    var subtitle: String {
        switch self {
        case .privateHome:
            return "Your personal collection of photos, created based on posts from users you follow."
        case .local:
            return "A collection of photos created from all posts made by users publishing on this server."
        case .global:
            return "A collection of photos created from all user-uploaded images that have reached this server."
        }
    }

    var navigationTitle: String {
        switch self {
        case .privateHome:
            return "Your timeline"
        case .local:
            return "Local timeline"
        case .global:
            return "Global timeline"
        }
    }
}
