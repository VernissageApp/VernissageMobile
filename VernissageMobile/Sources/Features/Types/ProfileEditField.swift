//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ProfileEditField: Identifiable {
    let id = UUID()
    var backendId: String?
    var key: String
    var value: String
}
