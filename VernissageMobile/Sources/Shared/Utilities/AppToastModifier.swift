//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct AppToastModifier: ViewModifier {
    @Binding var message: String?
    let style: Style

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let presentableMessage = presentableMessage {
                    ToastView(style: style, message: presentableMessage)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        .contentShape(.rect)
                        .onTapGesture {
                            dismissToast()
                        }
                        .transition(transition)
                        .task(id: presentableMessage) {
                            await scheduleDismiss(for: presentableMessage)
                        }
                }
            }
            .animation(animation, value: presentableMessage != nil)
    }

    private var presentableMessage: String? {
        message.flatMap { $0.toastPresentableMessage }
    }

    private var transition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity)
    }

    private var animation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.86)
    }

    private func dismissToast() {
        withAnimation(animation) {
            message = nil
        }
    }

    private func scheduleDismiss(for presentableMessage: String) async {
        try? await Task.sleep(for: .seconds(AppConstants.Toast.visibleDurationSeconds))
        guard !Task.isCancelled else {
            return
        }

        guard self.presentableMessage == presentableMessage else {
            return
        }

        await MainActor.run {
            dismissToast()
        }
    }

    enum Style {
        case error
        case warning
        case information
        case success

        var title: String {
            switch self {
            case .error:
                "Error"
            case .warning:
                "Warning"
            case .information:
                "Information"
            case .success:
                "Success"
            }
        }

        var iconName: String {
            switch self {
            case .error:
                "xmark.circle.fill"
            case .warning:
                "exclamationmark.triangle.fill"
            case .information:
                "info.circle.fill"
            case .success:
                "checkmark.circle.fill"
            }
        }

        var accentColor: Color {
            switch self {
            case .error:
                .red
            case .warning:
                .orange
            case .information:
                .blue
            case .success:
                .green
            }
        }
    }

    struct ToastView: View {
        let style: Style
        let message: String

        @Environment(\.colorScheme) private var colorScheme

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: style.iconName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(style.accentColor)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(style.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(primaryTextColor)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(secondaryTextColor)
                        .multilineTextAlignment(.leading)
                        .lineLimit(AppConstants.Toast.maxSubtitleLines)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                shape.fill(glassBaseTint)
            }
            .glassEffect(.regular, in: shape)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(style.accentColor)
                    .frame(width: 6)
            }
            .clipShape(shape)
            .overlay(
                shape.strokeBorder(borderColor, lineWidth: 1)
            )
            .shadow(color: shadowColor, radius: 12, x: 0, y: 4)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(style.title). \(message)")
            .accessibilityHint("Tap to dismiss.")
            .accessibilityAddTraits(.isButton)
        }

        private var glassBaseTint: Color {
            colorScheme == .dark
                ? Color.black.opacity(0.26)
                : Color.white.opacity(0.68)
        }

        private var primaryTextColor: Color {
            colorScheme == .dark ? .white : .black
        }

        private var secondaryTextColor: Color {
            colorScheme == .dark ? Color.white.opacity(0.96) : Color.black.opacity(0.90)
        }

        private var borderColor: Color {
            colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
        }

        private var shadowColor: Color {
            colorScheme == .dark ? Color.black.opacity(0.45) : Color.black.opacity(0.16)
        }
    }
}
