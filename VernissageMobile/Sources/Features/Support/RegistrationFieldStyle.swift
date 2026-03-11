//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct RegistrationFieldStyle: ViewModifier {
    let fillColor: Color
    let strokeColor: Color

    func body(content: Content) -> some View {
        content
            .padding(12)
            .foregroundStyle(.white)
            .background(fillColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(strokeColor, lineWidth: 1)
                    .allowsHitTesting(false)
            )
    }
}
