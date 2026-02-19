//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI
import AlertToast

extension View {
    func liquidGlassCard() -> some View {
        modifier(LiquidGlassCardModifier())
    }

    func errorAlertToast(_ message: Binding<String?>) -> some View {
        toast(isPresenting: Binding(
            get: { message.wrappedValue?.toastPresentableMessage != nil },
            set: { isPresented in
                if !isPresented {
                    message.wrappedValue = nil
                }
            }
        )) {
            AlertToast(
                displayMode: .alert,
                type: .error(.white.opacity(0.8)),
                title: message.wrappedValue?.toastPresentableMessage ?? "Error",
                style: .style(
                    backgroundColor: .red.opacity(0.8),
                    titleColor: .white.opacity(0.8),
                    subTitleColor: .white.opacity(0.8)
                )
            )
        }
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
