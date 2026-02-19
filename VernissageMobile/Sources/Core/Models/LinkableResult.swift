//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct LinkableResult<T: Decodable>: Decodable {
    let maxId: String?
    let minId: String?
    let data: [T]
}
