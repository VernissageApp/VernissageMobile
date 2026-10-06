//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

struct ExploreItem: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let amount: Int?
}
