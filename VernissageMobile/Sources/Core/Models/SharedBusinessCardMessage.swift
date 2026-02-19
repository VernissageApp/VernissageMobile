//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct SharedBusinessCardMessage: Codable, Hashable {
    var id: String?
    var message: String?
    var addedByUser: Bool?
    var createdAt: Date?
}
