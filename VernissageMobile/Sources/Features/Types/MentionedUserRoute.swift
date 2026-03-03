//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

struct MentionedUserRoute: Identifiable, Hashable {
    let userName: String
    let preferredDisplayName: String?

    var id: String {
        userName.lowercased()
    }
}
