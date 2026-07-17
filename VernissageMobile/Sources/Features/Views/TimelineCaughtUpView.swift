//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct TimelineCaughtUpView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize = 64.0

    var body: some View {
        VStack(spacing: 0) {
            Image(.caughtUp)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .accessibilityHidden(true)

            Text("You're all caught up")
                .font(.headline)
                .bold()
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.top, 12)

            Text("You've seen all new photos.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)

            HStack(spacing: 12) {
                Rectangle()
                    .fill(.tertiary)
                    .frame(height: 1)
                    .accessibilityHidden(true)

                Text("Older photos below")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .layoutPriority(1)

                Rectangle()
                    .fill(.tertiary)
                    .frame(height: 1)
                    .accessibilityHidden(true)
            }
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            colorScheme == .dark ? Color.white.opacity(0.09) : Color.secondary.opacity(0.06),
            in: .rect(cornerRadius: 16)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.tertiary, lineWidth: 1)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}
