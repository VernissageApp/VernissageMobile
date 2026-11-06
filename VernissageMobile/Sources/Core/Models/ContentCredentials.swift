//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

struct ContentCredentials: Identifiable, Sendable {
    var id: URL {
        imageURL
    }

    let imageURL: URL
    let author: String?
    let appOrDeviceUsed: String?
    let aiGenerated: Bool
    let identity: String?
    let actions: String?
    let title: String?
    let format: String?
    let claimGenerator: String?
    let softwareAgent: String?
    let signatureIssuer: String?
    let signatureTime: String?
    let ingredientsCount: Int
    let actionsCount: Int
    let validationStatuses: [ContentCredentialsValidationStatus]
    let verificationStatus: ContentCredentialsVerification
    let validationErrors: [ContentCredentialsValidationStatus]
    let validationState: String?
    let verifyURL: URL
    let manifest: ContentCredentialsJSON

    var signedAt: Date? {
        guard let signatureTime else {
            return nil
        }

        return (try? Date(signatureTime, strategy: .iso8601))
            ?? (try? Date(signatureTime, strategy: .iso8601.time(includingFractionalSeconds: true)))
    }
}
