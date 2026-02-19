//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct SearchResult: Decodable {
    let users: [User]?
    let statuses: [Status]?
    let hashtags: [Hashtag]?
}
