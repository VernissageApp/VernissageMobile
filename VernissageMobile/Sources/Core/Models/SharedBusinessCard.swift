//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct SharedBusinessCard: Decodable, Identifiable, Hashable {
    let id: String
    var businessCardId: String?
    var code: String?
    var title: String?
    var note: String?
    var thirdPartyName: String?
    var thirdPartyEmail: String?
    var revokedAt: Date?
    var createdAt: Date?
    var updatedAt: Date?
    var messages: [SharedBusinessCardMessage]?
}
extension SharedBusinessCard {
    var titleText: String {
        title?.nilIfEmpty ?? "Untitled"
    }
}
