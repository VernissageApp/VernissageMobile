//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

enum SaveRemoteImageError: LocalizedError {
    case photoLibraryAccessRequired
    case downloadFailed
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .photoLibraryAccessRequired:
            "Photo Library access is required to save images."
        case .downloadFailed:
            "Unable to download the image."
        case .saveFailed:
            "Unable to save the image to your photo library."
        }
    }
}
