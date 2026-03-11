//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

extension View {
    func liquidGlassCard() -> some View {
        modifier(LiquidGlassCardModifier())
    }

    func errorAlertToast(_ message: Binding<String?>) -> some View {
        modifier(AppToastModifier(message: message, style: .error))
    }

    func warningAlertToast(_ message: Binding<String?>) -> some View {
        modifier(AppToastModifier(message: message, style: .warning))
    }

    func informationAlertToast(_ message: Binding<String?>) -> some View {
        modifier(AppToastModifier(message: message, style: .information))
    }

    func successAlertToast(_ message: Binding<String?>) -> some View {
        modifier(AppToastModifier(message: message, style: .success))
    }

    @ViewBuilder
    func applyIfLet<T, Content: View>(_ value: T?, transform: (Self, T) -> Content) -> some View {
        if let value {
            transform(self, value)
        } else {
            self
        }
    }
}
public extension View {
    func onFirstAppear<ID: Equatable>(id value: ID, _ action: @escaping () async -> Void) -> some View {
        modifier(FirstAppearForId(id: value, action: action))
    }
    
    func onFirstAppear(_ action: @escaping () async -> Void) -> some View {
        modifier(FirstAppear(action: action))
    }
}
