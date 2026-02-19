//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

enum SharedBusinessCardSheetMode: Identifiable {
    case create
    case edit(SharedBusinessCard)

    var id: String {
        switch self {
        case .create:
            return "create"
        case .edit(let card):
            return "edit-\(card.id)"
        }
    }

    var title: String {
        switch self {
        case .create:
            return "Share business card"
        case .edit:
            return "Edit shared card"
        }
    }

    var submitTitle: String {
        switch self {
        case .create:
            return "Share"
        case .edit:
            return "Save"
        }
    }

    var initialTitle: String {
        switch self {
        case .create:
            return ""
        case .edit(let card):
            return card.title?.nilIfEmpty ?? ""
        }
    }

    var initialNote: String {
        switch self {
        case .create:
            return ""
        case .edit(let card):
            return card.note?.nilIfEmpty ?? ""
        }
    }

    var initialThirdPartyName: String {
        switch self {
        case .create:
            return ""
        case .edit(let card):
            return card.thirdPartyName?.nilIfEmpty ?? ""
        }
    }

    var initialThirdPartyEmail: String {
        switch self {
        case .create:
            return ""
        case .edit(let card):
            return card.thirdPartyEmail?.nilIfEmpty ?? ""
        }
    }
}
