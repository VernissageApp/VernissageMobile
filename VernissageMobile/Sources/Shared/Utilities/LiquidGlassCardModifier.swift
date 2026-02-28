//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct LiquidGlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    private var strokeColor: Color {
        colorScheme == .dark ? .white.opacity(0.20) : .black.opacity(0.10)
    }

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(strokeColor, lineWidth: 1)
            }
    }
}
