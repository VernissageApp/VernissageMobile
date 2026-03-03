//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

struct HashtagTimelineRoute: Identifiable, Hashable {
    let hashtagName: String

    var id: String {
        hashtagName.lowercased()
    }
}
