//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ProfileHeaderImageView: View {
    let urlString: String?

    var body: some View {
        AsyncImage(url: URL(string: urlString ?? "")) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            ZStack {
                LinearGradient(colors: [.gray.opacity(0.45), .black.opacity(0.35)],
                               startPoint: .top,
                               endPoint: .bottom)
                Image(systemName: "photo")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
        .overlay(
            LinearGradient(colors: [.clear, .black.opacity(0.18)],
                           startPoint: .center,
                           endPoint: .bottom)
        )
    }
}
