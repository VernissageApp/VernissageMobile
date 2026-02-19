//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct AsyncAvatarView: View {
    let urlString: String?
    var size: CGFloat = 44

    var body: some View {
        AsyncImage(url: URL(string: urlString ?? "")) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.18))

                Image(systemName: "person.fill")
                    .foregroundStyle(.white.opacity(0.78))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white.opacity(0.22), lineWidth: 1))
    }
}
