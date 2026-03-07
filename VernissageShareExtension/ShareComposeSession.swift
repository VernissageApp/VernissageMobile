//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation
import Observation

@MainActor
@Observable
final class ShareComposeSession {
    var attachmentURLs: [URL] = []
    var isPreparingAttachments = true
    var preparationErrorMessage: String?
}
