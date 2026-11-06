//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

enum ContentCredentialsVerification: Sendable {
    case verified
    case untrusted
    case invalid
    case unknown

    var label: String {
        switch self {
        case .verified:
            "C2PA integrity and signature trust verified"
        case .untrusted:
            "Integrity verified. Certificate issuer not verified"
        case .invalid:
            "C2PA integrity verification failed"
        case .unknown:
            "C2PA verification result is unavailable"
        }
    }

    var hasValidIntegrity: Bool {
        self == .verified || self == .untrusted
    }

    var symbol: String {
        switch self {
        case .verified, .untrusted:
            AppConstants.ContentCredentials.symbol
        case .invalid:
            "exclamationmark.triangle"
        case .unknown:
            "questionmark.circle"
        }
    }
}
