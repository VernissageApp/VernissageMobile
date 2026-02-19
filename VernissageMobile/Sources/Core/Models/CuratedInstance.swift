//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

struct CuratedInstance: Decodable, Identifiable {
    let name: String
    let url: String
    let imageURLString: String?
    let category: String?
    let language: String?
    let description: String?

    var id: String {
        url.lowercased()
    }

    var imageURL: URL? {
        guard let imageURLString = imageURLString?.nilIfEmpty else {
            return nil
        }

        return URL(string: imageURLString)
    }

    var displayCategory: String {
        (category?.nilIfEmpty ?? "General").uppercased()
    }

    var displayLanguage: String? {
        language?.nilIfEmpty?.uppercased()
    }

    var displayDescription: String {
        description?.nilIfEmpty ?? "No description provided."
    }

    enum CodingKeys: String, CodingKey {
        case name
        case url
        case imageURLString = "img"
        case category
        case language
        case description
    }
}

extension CuratedInstance {
    static let placeholders: [CuratedInstance] = [
        CuratedInstance(
            name: "loading.server.one",
            url: "https://loading.server.one",
            imageURLString: nil,
            category: "General",
            language: "EN",
            description: "Loading..."
        ),
        CuratedInstance(
            name: "loading.server.two",
            url: "https://loading.server.two",
            imageURLString: nil,
            category: "General",
            language: "EN",
            description: "Loading..."
        )
    ]
}
