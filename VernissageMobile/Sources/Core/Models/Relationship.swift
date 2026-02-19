//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct Relationship: Decodable {
    let userId: String?
    let following: Bool
    let followedBy: Bool
    let requested: Bool
    let requestedBy: Bool
    let mutedStatuses: Bool
    let mutedReblogs: Bool
    let mutedNotifications: Bool

    init(
        userId: String? = nil,
        following: Bool = false,
        followedBy: Bool = false,
        requested: Bool = false,
        requestedBy: Bool = false,
        mutedStatuses: Bool = false,
        mutedReblogs: Bool = false,
        mutedNotifications: Bool = false
    ) {
        self.userId = userId
        self.following = following
        self.followedBy = followedBy
        self.requested = requested
        self.requestedBy = requestedBy
        self.mutedStatuses = mutedStatuses
        self.mutedReblogs = mutedReblogs
        self.mutedNotifications = mutedNotifications
    }

    enum CodingKeys: String, CodingKey {
        case userId
        case following
        case followedBy
        case requested
        case requestedBy
        case mutedStatuses
        case mutedReblogs
        case mutedNotifications
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        following = try container.decodeIfPresent(Bool.self, forKey: .following) ?? false
        followedBy = try container.decodeIfPresent(Bool.self, forKey: .followedBy) ?? false
        requested = try container.decodeIfPresent(Bool.self, forKey: .requested) ?? false
        requestedBy = try container.decodeIfPresent(Bool.self, forKey: .requestedBy) ?? false
        mutedStatuses = try container.decodeIfPresent(Bool.self, forKey: .mutedStatuses) ?? false
        mutedReblogs = try container.decodeIfPresent(Bool.self, forKey: .mutedReblogs) ?? false
        mutedNotifications = try container.decodeIfPresent(Bool.self, forKey: .mutedNotifications) ?? false
    }

    var cacheKey: String {
        "\(userId ?? "none")|\(following)|\(followedBy)|\(requested)|\(requestedBy)|\(mutedStatuses)|\(mutedReblogs)|\(mutedNotifications)"
    }
}
