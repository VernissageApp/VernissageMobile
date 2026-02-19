//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ProfileFlagChipView: View {
    enum Style {
        case administrator
        case supporter

        var textColor: Color {
            switch self {
            case .administrator:
                return Color(red: 0.65, green: 0.08, blue: 0.16)
            case .supporter:
                return Color(red: 0.08, green: 0.34, blue: 0.78)
            }
        }

        var backgroundColor: Color {
            switch self {
            case .administrator:
                return Color(red: 0.92, green: 0.30, blue: 0.34).opacity(0.22)
            case .supporter:
                return Color(red: 0.24, green: 0.56, blue: 1.0).opacity(0.22)
            }
        }

        var borderColor: Color {
            switch self {
            case .administrator:
                return Color(red: 0.85, green: 0.22, blue: 0.28).opacity(0.55)
            case .supporter:
                return Color(red: 0.18, green: 0.45, blue: 0.95).opacity(0.55)
            }
        }
    }

    let title: String
    let systemImage: String
    let style: Style

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 16, height: 16, alignment: .center)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
        }
            .padding(.horizontal, 10)
            .frame(height: 34, alignment: .center)
            .foregroundStyle(style.textColor)
            .background(
                Capsule(style: .continuous)
                    .fill(style.backgroundColor)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(style.borderColor, lineWidth: 1)
            )
    }
}
