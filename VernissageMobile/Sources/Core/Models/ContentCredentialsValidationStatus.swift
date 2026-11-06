//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

struct ContentCredentialsValidationStatus: Sendable, Hashable {
    let code: String?
    let explanation: String?
    var success: Bool? = nil

    var message: String {
        switch code {
        case "claimSignature.mismatch":
            "The C2PA signature is invalid."
        case "assertion.dataHash.mismatch", "assertion.hashedURI.mismatch", "ingredient.manifest.mismatch":
            "The hash of the image or an ingredient does not match the C2PA manifest."
        default:
            explanation ?? code ?? "Unknown validation error"
        }
    }
}
