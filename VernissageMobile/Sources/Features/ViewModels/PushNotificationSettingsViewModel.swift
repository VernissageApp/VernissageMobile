//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation
import Observation

@MainActor
@Observable
final class PushNotificationSettingsViewModel {
    var settings = PushNotificationSettings()
    var isLoading = false
    var isSaving = false
    var errorMessage: String?

    private let registrationService = PushNotificationRegistrationService()

    var isPreferenceDisabled: Bool {
        !settings.notificationsEnabled || isSaving
    }

    func load(using appState: AppState) async {
        guard !isLoading else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            guard let account = appState.activeAccount,
                  let storedSubscription = try registrationService.loadStoredSubscription(for: account) else {
                return
            }

            settings = storedSubscription.settings
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func save(using appState: AppState) async -> Bool {
        guard !isSaving else {
            return false
        }

        isSaving = true
        defer { isSaving = false }

        do {
            _ = try await registrationService.save(settings: settings, using: appState)
            appState.showSuccessToast("Notification settings have been saved.")
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    func requestAuthorizationAfterEnabling() async {
        guard settings.notificationsEnabled else {
            return
        }

        do {
            let isAuthorized = try await registrationService.requestAuthorizationForSettings()
            if !isAuthorized {
                settings.notificationsEnabled = false
                errorMessage = PushNotificationError.permissionDenied.errorDescription
            }
        } catch {
            settings.notificationsEnabled = false
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
