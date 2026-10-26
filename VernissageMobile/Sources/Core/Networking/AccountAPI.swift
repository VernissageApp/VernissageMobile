//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

@MainActor
final class AccountAPI {
    private unowned let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func emailVerified() async throws -> BooleanResult {
        try await appState.api.authorizedRequest(
            account: appState.requireActiveAccount(),
            path: "/api/v1/account/email/verified",
            queryItems: []
        )
    }
}
