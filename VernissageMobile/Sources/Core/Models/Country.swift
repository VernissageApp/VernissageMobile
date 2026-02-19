//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct Country: Decodable, Identifiable, Hashable {
    let id: String?
    let name: String?
    let code: String?
}
