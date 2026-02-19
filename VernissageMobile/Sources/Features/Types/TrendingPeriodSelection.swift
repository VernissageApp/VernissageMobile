//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

enum TrendingPeriodSelection: String, CaseIterable, Hashable {
    case daily
    case monthly
    case yearly

    var title: String {
        switch self {
        case .daily:
            return "Day"
        case .monthly:
            return "Month"
        case .yearly:
            return "Year"
        }
    }
}
