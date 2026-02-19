//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct AttachmentFile: Decodable {
    let url: String?
    let width: CGFloat?
    let height: CGFloat?
    let aspect: CGFloat?
}
extension AttachmentFile {
    var aspectRatio: CGFloat? {
        if let aspect, aspect > 0 {
            return aspect
        }

        guard let width, let height, width > 0, height > 0 else {
            return nil
        }

        return width / height
    }
}
