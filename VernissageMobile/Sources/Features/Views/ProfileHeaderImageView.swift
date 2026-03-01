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
            abstractHeaderPlaceholder
        }
        .overlay(
            LinearGradient(colors: [.clear, .black.opacity(0.18)],
                           startPoint: .center,
                           endPoint: .bottom)
        )
    }

    private var abstractHeaderPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.14, green: 0.19, blue: 0.42),
                    Color(red: 0.36, green: 0.13, blue: 0.42),
                    Color(red: 0.11, green: 0.35, blue: 0.35)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color(red: 1.00, green: 0.30, blue: 0.38).opacity(0.95))
                .frame(width: 210, height: 210)
                .offset(x: -120, y: -48)
                .blur(radius: 52)

            Circle()
                .fill(Color(red: 1.00, green: 0.78, blue: 0.18).opacity(0.88))
                .frame(width: 220, height: 220)
                .offset(x: 8, y: -72)
                .blur(radius: 58)

            Circle()
                .fill(Color(red: 0.24, green: 0.86, blue: 0.34).opacity(0.85))
                .frame(width: 220, height: 220)
                .offset(x: 128, y: 16)
                .blur(radius: 56)

            Circle()
                .fill(Color(red: 0.16, green: 0.56, blue: 1.00).opacity(0.9))
                .frame(width: 245, height: 245)
                .offset(x: -16, y: 94)
                .blur(radius: 62)

            Circle()
                .fill(Color(red: 0.56, green: 0.30, blue: 1.00).opacity(0.85))
                .frame(width: 220, height: 220)
                .offset(x: 158, y: 88)
                .blur(radius: 58)
        }
        .overlay {
            Rectangle()
                .fill(.black.opacity(0.12))
        }
    }
}
