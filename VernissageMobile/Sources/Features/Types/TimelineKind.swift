//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

enum TimelineKind {
    case privateHome
    case local
    case editorsChoice
    case trending
    case global

    var path: String {
        switch self {
        case .privateHome:
            return "/api/v1/timelines/home"
        case .local:
            return "/api/v1/timelines/public"
        case .editorsChoice:
            return "/api/v1/timelines/featured-statuses"
        case .trending:
            return "/api/v1/trending/statuses"
        case .global:
            return "/api/v1/timelines/public"
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .privateHome:
            return [URLQueryItem(name: "limit", value: "40")]
        case .local:
            return [
                URLQueryItem(name: "limit", value: "40"),
                URLQueryItem(name: "onlyLocal", value: "true")
            ]
        case .editorsChoice:
            return [URLQueryItem(name: "limit", value: "40")]
        case .trending:
            return [
                URLQueryItem(name: "limit", value: "40"),
                URLQueryItem(name: "period", value: "daily")
            ]
        case .global:
            return [URLQueryItem(name: "limit", value: "40")]
        }
    }
}
