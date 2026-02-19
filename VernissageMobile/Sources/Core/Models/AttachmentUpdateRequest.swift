//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct AttachmentUpdateRequest: Encodable {
    let id: String
    let url = ""
    let previewUrl = ""
    let description: String?
    let blurhash: String?
    let make: String?
    let model: String?
    let lens: String?
    let createDate: String?
    let focalLength: String?
    let focalLenIn35mmFilm: String?
    let fNumber: String?
    let exposureTime: String?
    let photographicSensitivity: String?
    let software: String?
    let film: String?
    let chemistry: String?
    let scanner: String?
    let locationId: String?
    let licenseId: String?
    let latitude: String?
    let longitude: String?
    let flash: String?
}
