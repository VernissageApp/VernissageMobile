//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

struct DirectMessagesPage<Item: Decodable & Sendable>: Decodable, Sendable {
    let data: [Item]
    let page: Int
    let size: Int
    let total: Int

    var hasMore: Bool {
        page * size < total
    }
}
