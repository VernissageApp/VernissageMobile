//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct TimelineCaughtUpView: View {
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize = 66.0

    var body: some View {
        VStack(spacing: 0) {
            Image(.caughtUp)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .padding(9)
                .glassEffect(
                    .regular.tint(Color.primary.opacity(0.10)),
                    in: .circle
                )
                .shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 5)
                .accessibilityHidden(true)

            Text("You're all caught up")
                .font(.headline)
                .bold()
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.top, 16)

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
            .padding(.top, 24)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
        .accessibilityElement(children: .combine)
    }
}
