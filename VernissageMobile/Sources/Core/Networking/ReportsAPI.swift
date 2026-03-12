//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

@MainActor
final class ReportsAPI {
    private unowned let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func createReport(
        reportedUserId: String,
        statusId: String?,
        comment: String?,
        category: String?,
        ruleIds: [Int],
        forward: Bool
    ) async throws {
        let account = try appState.requireActiveAccount()

        let payload = ReportRequestBody(
            reportedUserId: reportedUserId,
            statusId: statusId?.nilIfEmpty,
            comment: comment?.nilIfEmpty,
            forward: forward,
            category: category?.nilIfEmpty,
            ruleIds: ruleIds.isEmpty ? nil : ruleIds
        )

        try await appState.api.authorizedRequestNoContent(
            account: account,
            path: "/api/v1/reports",
            method: "POST",
            queryItems: [],
            additionalHeaders: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(payload)
        )
    }
}
