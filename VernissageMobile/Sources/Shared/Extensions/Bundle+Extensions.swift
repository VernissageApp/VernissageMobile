//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

extension Bundle {
    var appVersionLabel: String {
        switch (appShortVersion, appBuildVersion) {
        case let (.some(short), .some(build)):
            return "\(short) (\(build))"
        case let (.some(short), .none):
            return short
        case let (.none, .some(build)):
            return build
        default:
            return "Unknown"
        }
    }

    private var appShortVersion: String? {
        (object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)?.nilIfEmpty
    }

    private var appBuildVersion: String? {
        (object(forInfoDictionaryKey: "CFBundleVersion") as? String)?.nilIfEmpty
    }
}
