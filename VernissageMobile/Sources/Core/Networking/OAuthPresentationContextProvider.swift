//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI
import AuthenticationServices

@MainActor
final class OAuthPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
#if SHARE_EXTENSION
        preconditionFailure("OAuth presentation is unavailable in share extension.")
#else
        let windowScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }

        if let scene = windowScenes.first,
           let keyWindow = scene.windows.first(where: { $0.isKeyWindow }) {
            return keyWindow
        }

        if let fallbackScene = windowScenes.first,
           let anyWindow = fallbackScene.windows.first {
            return anyWindow
        }

        if let fallbackScene = windowScenes.first {
            return ASPresentationAnchor(windowScene: fallbackScene)
        }

        preconditionFailure("No UIWindowScene available for ASWebAuthenticationSession presentation.")
#endif
    }
}
