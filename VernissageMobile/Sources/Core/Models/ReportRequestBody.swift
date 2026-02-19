//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ReportRequestBody: Encodable {
    let reportedUserId: String
    let statusId: String?
    let comment: String?
    let forward: Bool
    let category: String?
    let ruleIds: [Int]?
}
