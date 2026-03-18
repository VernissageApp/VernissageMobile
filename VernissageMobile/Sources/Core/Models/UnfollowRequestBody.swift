//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

struct UnfollowRequestBody: Encodable {
    let removeStatusesFromTimeline: Bool
    let removeReblogsFromTimeline: Bool
}
