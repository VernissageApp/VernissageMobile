//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

enum ServerVersion {
    static func supportsDirectMessages(_ version: String?) -> Bool {
        guard let version else {
            return false
        }

        let normalized = version.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutPrefix = normalized.hasPrefix("v") ? String(normalized.dropFirst()) : normalized
        let release = withoutPrefix.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "-" || $0 == "+" }).first ?? ""
        let parts = release.split(separator: ".", omittingEmptySubsequences: false)

        guard parts.count == 3, parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }),
              let major = Int(parts[0]), let minor = Int(parts[1]), let patch = Int(parts[2]) else {
            return false
        }

        // Compare numeric components so versions such as 1.100.0 sort after 1.45.0.
        return [major, minor, patch].lexicographicallyPrecedes(AppConstants.DirectMessages.minimumVersion) == false
    }
}
