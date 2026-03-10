//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct CuratedInstanceCardView: View {
    let instance: CuratedInstance
    let onChoose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerImage

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 8) {
                    Text(instance.displayCategory)
                        .font(.caption.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.72))

                    if let language = instance.displayLanguage {
                        Text(language)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.white.opacity(0.14), in: Capsule(style: .continuous))
                    }
                }

                Text(instance.name)
                    .font(.title3.bold())
                    .foregroundStyle(.white)

                Text(instance.displayDescription)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onChoose) {
                    Text("Choose server")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .foregroundStyle(.blue)
                .background(.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(.blue, lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var headerImage: some View {
        if let imageURL = instance.imageURL {
            AsyncImage(url: imageURL, transaction: Transaction(animation: .easeInOut(duration: 0.22))) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    placeholderHeader
                case .empty:
                    placeholderHeader
                @unknown default:
                    placeholderHeader
                }
            }
            .frame(height: 150)
            .frame(maxWidth: .infinity)
            .clipped()
        } else {
            placeholderHeader
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .clipped()
        }
    }

    private var placeholderHeader: some View {
        LinearGradient(
            colors: [
                Color(red: 0.17, green: 0.31, blue: 0.22),
                Color(red: 0.06, green: 0.15, blue: 0.23),
                Color.black.opacity(0.85)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
