//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

extension Optional where Wrapped == String {
    var nilIfEmpty: String? {
        switch self {
        case .none:
            return nil
        case .some(let value):
            return value.nilIfEmpty
        }
    }
}
