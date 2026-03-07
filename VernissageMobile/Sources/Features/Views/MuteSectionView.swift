//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct MuteSectionView: View {
    @Environment(\.colorScheme) private var colorScheme

    let relationship: Relationship

    private var borderColor: Color {
        colorScheme == .dark ? .black : .white
    }

    private var backgroundColor: Color {
        colorScheme == .dark
            ? Color(red: 0.22, green: 0.22, blue: 0.24)
            : Color(red: 0.90, green: 0.90, blue: 0.92)
    }

    private var mutedScopeIcons: [String] {
        var icons: [String] = []

        if relationship.mutedStatuses {
            icons.append("photo")
        }

        if relationship.mutedReblogs {
            icons.append("arrow.2.squarepath")
        }

        if relationship.mutedNotifications {
            icons.append("bell")
        }

        return icons
    }

    private var accessibilityDescription: String {
        var items: [String] = []

        if relationship.mutedStatuses {
            items.append("new statuses")
        }

        if relationship.mutedReblogs {
            items.append("reblogs")
        }

        if relationship.mutedNotifications {
            items.append("notifications")
        }

        if items.isEmpty {
            return "Muted"
        }

        return "Muted \(items.joined(separator: ", "))"
    }

    var body: some View {
        HStack(spacing: 6) {
            Text("Muted")
                .font(.subheadline)
                .bold()

            ForEach(mutedScopeIcons, id: \.self) { systemImage in
                Image(systemName: systemImage)
                    .font(.footnote.weight(.semibold))
                    .accessibilityHidden(true)
            }
        }
        .lineLimit(1)
        .padding(.horizontal, 10)
        .frame(minHeight: 30)
        .foregroundStyle(.secondary)
        .background {
            Capsule()
                .fill(backgroundColor)
        }
        .overlay {
            Capsule()
                .stroke(borderColor, lineWidth: 3)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }
}
