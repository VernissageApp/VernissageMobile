//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

@MainActor
final class TimelineMarkersAPI {
    private unowned let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func fetchMarker(for timeline: TimelineMarkerTimeline) async throws -> TimelineMarker? {
        let account = try appState.requireActiveAccount()

        do {
            return try await appState.api.authorizedRequest(
                account: account,
                path: "/api/v1/timeline-markers/\(timeline.rawValue)",
                queryItems: [],
                showToastOnError: false
            )
        } catch let APIError.http(statusCode, _) where statusCode == 404 {
            return nil
        }
    }

    func updateMarker(for timeline: TimelineMarkerTimeline, statusId: String) async throws {
        let account = try appState.requireActiveAccount()
        let marker = TimelineMarker(statusId: statusId)

        try await appState.api.authorizedRequestNoContent(
            account: account,
            path: "/api/v1/timeline-markers/\(timeline.rawValue)",
            method: "POST",
            queryItems: [],
            additionalHeaders: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(marker),
            showToastOnError: false
        )
    }
}
