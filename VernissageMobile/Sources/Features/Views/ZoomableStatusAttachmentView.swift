//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ZoomableStatusAttachmentView: View {
    let attachment: Attachment
    let localImage: UIImage?
    let backgroundColor: Color
    let onZoomStateChanged: (Bool) -> Void
    let onDominantColorChanged: (UIColor) -> Void

    var body: some View {
        ZoomableAttachmentScrollView(
            imageURLString: attachment.orginalImageURL,
            localImage: localImage,
            blurHash: attachment.blurhash,
            onZoomStateChanged: onZoomStateChanged,
            onDominantColorChanged: onDominantColorChanged
        )
        .background(backgroundColor)
    }
}
