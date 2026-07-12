//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

struct PushSubscriptionKeyStore {
    private let keychainStore = KeychainStore(
        service: AppConstants.PushNotifications.keychainService,
        accessGroup: AppConstants.PushNotifications.keychainAccessGroup
    )

    func save(_ subscription: StoredPushSubscription) throws {
        let data = try JSONEncoder().encode(subscription)
        try keychainStore.save(data, account: subscription.subscriptionId)
    }

    func load(subscriptionId: String) throws -> StoredPushSubscription? {
        guard let data = try keychainStore.load(account: subscriptionId) else {
            return nil
        }

        return try JSONDecoder().decode(StoredPushSubscription.self, from: data)
    }

    func delete(subscriptionId: String) throws {
        try keychainStore.delete(account: subscriptionId)
    }
}
