//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct AttachmentExif: Decodable {
    let make: String?
    let model: String?
    let lens: String?
    let createDate: String?
    let focalLenIn35mmFilm: String?
    let fNumber: String?
    let exposureTime: String?
    let photographicSensitivity: String?
    let software: String?
    let film: String?
    let chemistry: String?
    let scanner: String?
    let latitude: String?
    let longitude: String?
    let flash: String?
    let focalLength: String?
}
extension AttachmentExif {
    var cameraDisplayLabel: String? {
        let make = make?.nilIfEmpty
        let model = model?.nilIfEmpty

        switch (make, model) {
        case let (.some(make), .some(model)):
            return "\(make) \(model)"
        case let (.some(make), .none):
            return make
        case let (.none, .some(model)):
            return model
        default:
            return nil
        }
    }

    var exposureDisplayLabel: String? {
        var parts: [String] = []

        if let focal = cleanedFocalLength {
            parts.append("\(focal)mm")
        }

        if let fNumber = fNumber?.nilIfEmpty {
            parts.append(String(fNumber.prefix(7)))
        }

        if let exposureTime = exposureTime?.nilIfEmpty {
            parts.append("\(exposureTime)s")
        }

        if let iso = photographicSensitivity?.nilIfEmpty {
            parts.append("ISO \(iso)")
        }

        return parts.isEmpty ? nil : parts.joined(separator: "   ")
    }

    var createDateDisplayLabel: String? {
        guard let createDate = createDate?.nilIfEmpty else {
            return nil
        }

        if let parsed = DateParser.parse(createDate) {
            return parsed.shortDateAndTimeLabel
        }

        return createDate
    }

    private var cleanedFocalLength: String? {
        let value = focalLength?.nilIfEmpty ?? focalLenIn35mmFilm?.nilIfEmpty
        guard let value else {
            return nil
        }

        let noMillimeters = value
            .replacingOccurrences(of: "mm", with: "", options: [.caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return noMillimeters
            .components(separatedBy: CharacterSet(charactersIn: ".,"))
            .first?
            .nilIfEmpty
    }

    var hasDisplayableMetadata: Bool {
        cameraDisplayLabel != nil ||
        lens?.nilIfEmpty != nil ||
        exposureDisplayLabel != nil ||
        flash?.nilIfEmpty != nil ||
        software?.nilIfEmpty != nil ||
        film?.nilIfEmpty != nil ||
        chemistry?.nilIfEmpty != nil ||
        scanner?.nilIfEmpty != nil ||
        createDateDisplayLabel != nil
    }
}
