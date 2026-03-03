//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

struct CategoryTimelineRoute: Identifiable, Hashable {
    let categoryName: String

    var id: String {
        categoryName.lowercased()
    }
}
