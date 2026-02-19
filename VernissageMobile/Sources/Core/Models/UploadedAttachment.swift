//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct UploadedAttachment: Decodable {
    let id: String
    let url: String?
    let previewUrl: String?
    let description: String?
    let blurhash: String?
}
