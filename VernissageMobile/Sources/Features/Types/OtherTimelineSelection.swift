//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

enum OtherTimelineSelection: String, CaseIterable, Hashable {
    case local
    case global

    var kind: TimelineKind {
        switch self {
        case .local:
            return .local
        case .global:
            return .global
        }
    }

    var label: String {
        switch self {
        case .local:
            return "Local"
        case .global:
            return "Global"
        }
    }

    var subtitle: String {
        switch self {
        case .local:
            return "A collection of photos created from all posts made by users publishing on this server."
        case .global:
            return "A collection of photos created from all user-uploaded images that have reached this server."
        }
    }
}
