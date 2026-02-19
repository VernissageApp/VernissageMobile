//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct StatusContext: Decodable {
    let ancestors: [Status]
    let descendants: [Status]

    enum CodingKeys: String, CodingKey {
        case ancestors
        case descendants
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ancestors = try container.decodeIfPresent([Status].self, forKey: .ancestors) ?? []
        descendants = try container.decodeIfPresent([Status].self, forKey: .descendants) ?? []
    }
}
