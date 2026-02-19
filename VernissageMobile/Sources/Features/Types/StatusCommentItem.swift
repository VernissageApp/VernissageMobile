//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct StatusCommentItem: Identifiable {
    let status: Status
    let isIndented: Bool

    var id: String { status.id }
}
