//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

extension Image {
    init?(blurHash: String, size: CGSize = CGSize(width: 32, height: 32), punch: Float = 1) {
        guard let uiImage = UIImage(blurHash: blurHash, size: size, punch: punch) else {
            return nil
        }

        self = Image(uiImage: uiImage)
    }
}
