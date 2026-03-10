//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct InstanceDetails: Decodable {
    let uri: String?
    let title: String?
    let description: String?
    let longDescription: String?
    let email: String?
    let version: String?
    let thumbnail: String?
    let languages: [String]?
    let registrationOpened: Bool?
    let registrationByApprovalOpened: Bool?
    let registrationByInvitationsOpened: Bool?
    let configuration: InstanceConfiguration?
    let contact: User?
    let rules: [InstanceRule]?
}
extension InstanceDetails {
    var longDescriptionMarkdown: String? {
        guard let longDescription = longDescription?.nilIfEmpty else {
            return nil
        }

        let markdown = try? longDescription.parseToMarkdown()
        return markdown?.nilIfEmpty ?? longDescription.strippedHTML
    }
}
