//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ReplySheetTarget: Identifiable {
    let status: Status
    let mode: ReplySheetMode

    var id: String { "\(mode.rawValue)-\(status.id)" }

    var displayUserName: String {
        if let userName = status.user?.userName?.trimmingPrefix("@").nilIfEmpty {
            return "@\(userName)"
        }

        return "selected user"
    }

    var headerText: String {
        switch mode {
        case .comment:
            return "Commenting to \(displayUserName)"
        case .reply:
            return "Replying to \(displayUserName)"
        }
    }

    var sheetTitle: String {
        switch mode {
        case .comment:
            return "Add comment"
        case .reply:
            return "Reply"
        }
    }
}
