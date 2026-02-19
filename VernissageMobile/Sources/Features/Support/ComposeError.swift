//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

enum ComposeError: LocalizedError {
    case uploadPreparationFailed
    case missingUploadedAttachments

    var errorDescription: String? {
        switch self {
        case .uploadPreparationFailed:
            return "Cannot prepare selected photo for upload."
        case .missingUploadedAttachments:
            return "At least one selected photo failed to upload."
        }
    }
}
