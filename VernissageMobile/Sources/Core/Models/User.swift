//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct User: Decodable {
    let id: String?
    let userName: String?
    let account: String?
    let name: String?
    let email: String?
    let url: String?
    let activityPubProfile: String?
    let bio: String?
    let bioHtml: String?
    let avatarUrl: String?
    let headerUrl: String?
    let locale: String?
    let isLocal: Bool?
    let roles: [String]?
    let manuallyApprovesFollowers: Bool?
    let includePublicPostsInSearchEngines: Bool?
    let includeProfilePageInSearchEngines: Bool?
    let featured: Bool?
    let isSupporter: Bool?
    let isSupporterFlagEnabled: Bool?
    let fields: [FlexiField]?
    let createdAt: Date?

    let photosCount: Int?
    let statusesCount: Int?
    let followersCount: Int?
    let followingCount: Int?
}
extension User {
    var uniquenessKey: String {
        if let id = id?.nilIfEmpty {
            return "id:\(id)"
        }

        if let normalizedUserName = userName?.trimmingPrefix("@").lowercased().nilIfEmpty {
            return "user:\(normalizedUserName)"
        }

        return "name:\((name ?? "").lowercased())|avatar:\((avatarUrl ?? "").lowercased())"
    }

    var displayBio: String? {
        if let bio = bio?.nilIfEmpty {
            return bio.withProfileSoftBreaks
        }

        return bioHtml?.nilIfEmpty?.strippedHTML.withProfileSoftBreaks
    }

    var displayBioMarkdown: String? {
        if let bioHtml = bioHtml?.nilIfEmpty {
            let markdown = try? bioHtml.parseToMarkdown()
        
            return markdown?.nilIfEmpty ?? bioHtml.strippedHTML.withProfileSoftBreaks
        }

        return bio?.nilIfEmpty
    }

    var blockingDomain: String? {
        func host(from rawValue: String?) -> String? {
            guard let rawValue = rawValue?.nilIfEmpty else {
                return nil
            }

            if let host = URL(string: rawValue)?.host?.nilIfEmpty {
                return host.lowercased()
            }

            if let host = URL(string: "https://\(rawValue)")?.host?.nilIfEmpty {
                return host.lowercased()
            }

            return nil
        }

        if let account = account?.trimmingPrefix("@").nilIfEmpty {
            let components = account.split(separator: "@")
            if components.count >= 2 {
                return String(components.last ?? "").lowercased().nilIfEmpty
            }
        }

        if let host = host(from: activityPubProfile) {
            return host
        }

        if let host = host(from: url) {
            return host
        }

        guard let normalizedUserName = userName?.trimmingPrefix("@").nilIfEmpty else {
            return nil
        }

        let components = normalizedUserName.split(separator: "@")
        guard components.count >= 2 else {
            return nil
        }

        return String(components.last ?? "").lowercased().nilIfEmpty
    }
}
