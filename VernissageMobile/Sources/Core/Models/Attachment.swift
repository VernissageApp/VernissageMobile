//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct Attachment: Decodable {
    let id: String?
    let smallFile: AttachmentFile?
    let originalFile: AttachmentFile?
    let blurhash: String?
    let description: String?
    let metadata: AttachmentMetadata?
    let location: AttachmentLocation?
    let license: AttachmentLicense?
}
extension Attachment {
    var smallImageURL: String? {
        smallFile?.url?.nilIfEmpty ?? originalFile?.url?.nilIfEmpty
    }
    
    var orginalImageURL: String? {
        originalFile?.url?.nilIfEmpty ?? smallFile?.url?.nilIfEmpty
    }

    var aspectRatio: CGFloat? {
        smallFile?.aspectRatio ?? originalFile?.aspectRatio
    }

    var locationDisplayLabel: String? {
        let locationName = location?.name?.nilIfEmpty
        let countryName = location?.country?.name?.nilIfEmpty

        switch (locationName, countryName) {
        case let (.some(name), .some(country)):
            return "\(name) (\(country))"
        case let (.some(name), .none):
            return name
        case let (.none, .some(country)):
            return country
        default:
            return nil
        }
    }

    var licenseDisplayLabel: String? {
        let name = license?.name?.nilIfEmpty
        let code = license?.code?.nilIfEmpty

        switch (name, code) {
        case let (.some(name), .some(code)):
            return "\(name) (\(code))"
        case let (.some(name), .none):
            return name
        case let (.none, .some(code)):
            return code
        default:
            return nil
        }
    }

    var openStreetMapURL: URL? {
        guard let latitude = mapLatitude?.nilIfEmpty,
              let longitude = mapLongitude?.nilIfEmpty else {
            return nil
        }

        let urlString = "https://www.openstreetmap.org/?mlat=\(latitude)&mlon=\(longitude)#map=10/\(latitude)/\(longitude)"
        return URL(string: urlString)
    }

    private var mapLatitude: String? {
        if let fromExif = metadata?.exif?.latitude?.normalizedLatitudeCoordinate {
            return fromExif
        }

        return location?.latitude?.normalizedDecimalCoordinate
    }

    private var mapLongitude: String? {
        if let fromExif = metadata?.exif?.longitude?.normalizedLongitudeCoordinate {
            return fromExif
        }

        return location?.longitude?.normalizedDecimalCoordinate
    }

    var hasDisplayableMetadata: Bool {
        locationDisplayLabel != nil ||
        licenseDisplayLabel != nil ||
        metadata?.exif?.hasDisplayableMetadata == true
    }
}
