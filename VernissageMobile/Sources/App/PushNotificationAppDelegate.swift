//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import UIKit
import UserNotifications

@MainActor
final class PushNotificationAppDelegate: NSObject, UIApplicationDelegate {
    static private(set) weak var current: PushNotificationAppDelegate?

    private var tokenContinuation: CheckedContinuation<Data, Error>?

    override init() {
        super.init()
        Self.current = self
        UNUserNotificationCenter.current().delegate = self
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        tokenContinuation?.resume(returning: deviceToken)
        tokenContinuation = nil
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        tokenContinuation?.resume(throwing: error)
        tokenContinuation = nil
    }

    func registerForRemoteNotifications() async throws -> Data {
        if let tokenContinuation {
            tokenContinuation.resume(throwing: PushNotificationError.deviceTokenUnavailable)
            self.tokenContinuation = nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            tokenContinuation = continuation
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
}

extension PushNotificationAppDelegate: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                             willPresent notification: UNNotification,
                                             withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void) {
        Task { @MainActor in
            notifyPushNotificationReceived()
            completionHandler([.badge, .banner, .list, .sound])
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                             didReceive response: UNNotificationResponse,
                                             withCompletionHandler completionHandler: @escaping @Sendable () -> Void) {
        Task { @MainActor in
            notifyPushNotificationReceived()
            completionHandler()
        }
    }

    private func notifyPushNotificationReceived() {
        NotificationCenter.default.post(name: .pushNotificationReceived, object: nil)
    }
}
