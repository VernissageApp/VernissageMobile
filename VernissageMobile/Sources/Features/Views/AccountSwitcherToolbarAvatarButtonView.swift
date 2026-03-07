//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct AccountSwitcherToolbarAvatarButtonView: View {
    let avatarURL: String?
    let onTap: () -> Void
    let onLongPress: () -> Void
    @State private var longPressHandled = false
    @State private var feedbackTrigger = false

    var body: some View {
        Button(action: handleTap) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.15))

                AsyncImage(url: URL(string: avatarURL ?? "")) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "person.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(.white.opacity(0.55), lineWidth: 1)
            )
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45, maximumDistance: 30)
                .onEnded { _ in
                    handleLongPress()
                }
        )
        .sensoryFeedback(.impact, trigger: feedbackTrigger)
        .accessibilityLabel("Open profile")
        .accessibilityHint("Long press to switch accounts")
    }

    private func handleTap() {
        if longPressHandled {
            longPressHandled = false
            return
        }

        onTap()
    }

    private func handleLongPress() {
        longPressHandled = true
        feedbackTrigger.toggle()
        onLongPress()
    }
}
