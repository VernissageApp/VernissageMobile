//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import CoreGraphics

enum AppConstants {
    enum Copy {
        static let fediverseServerDescription = "Vernissage is part of the Fediverse, a network of independently run servers. Your account is hosted on one server, and each server has its own rules and administrators. Whichever server you choose, you can still follow and interact with people across Vernissage, Mastodon, Pixelfed, and other compatible platforms."
        static let instanceURLRequired = "Instance URL is required"
    }

    enum StorageKeys {
        static let settingsAlwaysShowNsfw = "settings.alwaysShowNsfw"
        static let settingsShowAlternativeText = "settings.showAlternativeText"
        static let settingsShowAvatarsOnTimeline = "settings.showAvatarsOnTimeline"
        static let settingsShowImageCountsOnTimeline = "settings.showImageCountsOnTimeline"
        static let settingsAppIconName = "settings.appIconName"

        static let composeAttachmentDetailsLicenseId = "compose.attachmentDetails.licenseId"
        static let composeAttachmentDetailsCountryCode = "compose.attachmentDetails.countryCode"
        static let composeAttachmentDetailsCountryName = "compose.attachmentDetails.countryName"
        static let composeAttachmentDetailsCityName = "compose.attachmentDetails.cityName"
        static let composeAttachmentDetailsLocationId = "compose.attachmentDetails.locationId"
        static let composeSelectedCategoryId = "compose.selectedCategoryId"
    }

    enum MediaUpload {
        static let longestEdge4K: CGFloat = 4096
        static let longestEdge2K: CGFloat = 2048
        static let profileMaxUploadBytes = 2 * 1024 * 1024
    }

    enum OAuth {
        static let clientName = "Vernissage iOS"
        static let redirectURI = "vernissage-mobile://oauth-callback"
        static let scope = "read write profile"
    }

    enum Toast {
        static let visibleDurationSeconds: Double = 5
        static let maxSubtitleLines = 6
    }
}
