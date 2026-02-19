//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct AttachmentBlurHashPlaceholderView: View {
    let blurHash: String?
    let cornerRadius: CGFloat
    let aspectRatio: CGFloat?
    let fixedHeight: CGFloat?

    var body: some View {
        Group {
            if let blurHash = blurHash?.nilIfEmpty,
               let blurImage = Image(blurHash: blurHash) {
                blurImage
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(.white.opacity(0.08))
            }
        }
        .frame(maxWidth: .infinity)
        .applyIfLet(aspectRatio) { view, ratio in
            view.aspectRatio(ratio, contentMode: .fit)
        }
        .applyIfLet(fixedHeight) { view, height in
            view.frame(height: height)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
