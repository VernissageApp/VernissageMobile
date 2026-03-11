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
        ), duration: 5) {
            AlertToast(
                displayMode: .alert,
                type: .regular,
                title: "Error",
                subTitle: message.wrappedValue?.toastPresentableMessage ?? "",
                style: .style(
                    backgroundColor: .red,
                    titleColor: .white,
                    subTitleColor: .white,
                    titleFont: .headline.weight(.semibold),
                    subTitleFont: .body
                )
            )
        }
    }

    func warningAlertToast(_ message: Binding<String?>) -> some View {
        toast(isPresenting: Binding(
            get: { message.wrappedValue?.toastPresentableMessage != nil },
            set: { isPresented in
                if !isPresented {
                    message.wrappedValue = nil
                }
            }
        ), duration: 5) {
            AlertToast(
                displayMode: .alert,
                type: .regular,
                title: "Information",
                subTitle: message.wrappedValue?.toastPresentableMessage ?? "",
                style: .style(
                    backgroundColor: .orange,
                    titleColor: .white,
                    subTitleColor: .white,
                    titleFont: .headline.weight(.semibold),
                    subTitleFont: .body.weight(.semibold)
                )
            )
        }
    }

    func successAlertToast(_ message: Binding<String?>) -> some View {
        toast(isPresenting: Binding(
            get: { message.wrappedValue?.toastPresentableMessage != nil },
            set: { isPresented in
                if !isPresented {
                    message.wrappedValue = nil
                }
            }
        ), duration: 5) {
            AlertToast(
                displayMode: .alert,
                type: .regular,
                title: "Success",
                subTitle: message.wrappedValue?.toastPresentableMessage ?? "",
                style: .style(
                    backgroundColor: Color(red: 0.10, green: 0.58, blue: 0.21),
                    titleColor: .white,
                    subTitleColor: .white,
                    titleFont: .headline.weight(.semibold),
                    subTitleFont: .body.weight(.semibold)
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
