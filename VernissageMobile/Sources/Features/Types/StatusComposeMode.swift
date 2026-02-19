//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

enum StatusComposeMode {
    case create
    case edit(status: Status)

    var navigationTitle: String {
        switch self {
        case .create:
            return "Compose"
        case .edit:
            return "Edit status"
        }
    }

    var publishTitle: String {
        switch self {
        case .create:
            return "Publish"
        case .edit:
            return "Save"
        }
    }

    var editingStatus: Status? {
        if case .edit(let status) = self {
            return status
        }

        return nil
    }
}
