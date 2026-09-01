//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

enum ExploreContentSelection: String, CaseIterable, Hashable {
    case categories
    case cameras
    case lenses
    case films

    var title: String {
        switch self {
        case .categories:
            return "Categories"
        case .cameras:
            return "Cameras"
        case .lenses:
            return "Lenses"
        case .films:
            return "Films"
        }
    }

    var singularTitle: String {
        switch self {
        case .categories:
            return "category"
        case .cameras:
            return "camera"
        case .lenses:
            return "lens"
        case .films:
            return "film"
        }
    }

    var subtitle: String {
        switch self {
        case .categories:
            return "Browse photos grouped by category."
        case .cameras:
            return "Browse photos taken with a specific camera."
        case .lenses:
            return "Browse photos taken with a specific lens."
        case .films:
            return "Browse photos made with a specific film stock."
        }
    }

    var searchPrompt: String {
        switch self {
        case .categories:
            return "Filter categories"
        case .cameras:
            return "Search cameras"
        case .lenses:
            return "Search lenses"
        case .films:
            return "Search films"
        }
    }

    var emptySystemImage: String {
        switch self {
        case .categories:
            return "square.grid.2x2"
        case .cameras:
            return "camera"
        case .lenses:
            return "camera.aperture"
        case .films:
            return "film.stack"
        }
    }
}
