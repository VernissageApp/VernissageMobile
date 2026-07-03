//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

enum KeychainStoreError: LocalizedError {
    case write(OSStatus)
    case read(OSStatus)

    var errorDescription: String? {
        switch self {
        case .write(let status):
            "Cannot write to Keychain (\(status))."
        case .read(let status):
            "Cannot read from Keychain (\(status))."
        }
    }
}
