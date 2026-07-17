//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

enum TimelineMarkerTimeline: String, Sendable {
    case `private`
    case local
    case federated
    case featured
}
