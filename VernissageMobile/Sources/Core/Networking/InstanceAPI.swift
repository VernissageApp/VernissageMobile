//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

@MainActor
final class InstanceAPI {
    private unowned let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func fetchInstanceDetails() async throws -> InstanceDetails {
        let account = try appState.requireActiveAccount()

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/instance",
            queryItems: []
        )
    }
    
    func fetchInstanceRules() async throws -> [InstanceRule] {
        let instance = try await fetchInstanceDetails()
        return (instance.rules ?? []).sorted { $0.id < $1.id }
    }
}
