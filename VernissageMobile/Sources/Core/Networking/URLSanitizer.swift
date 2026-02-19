//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

enum URLSanitizer {
    static func sanitizeBaseURL(_ raw: String) throws -> URL {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if !value.lowercased().hasPrefix("http://") && !value.lowercased().hasPrefix("https://") {
            value = "https://\(value)"
        }

        guard let url = URL(string: value),
              let scheme = url.scheme,
              (scheme == "http" || scheme == "https"),
              url.host != nil else {
            throw APIError.invalidInstanceURL
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.path = ""
        components?.query = nil
        components?.fragment = nil

        guard let sanitized = components?.url else {
            throw APIError.invalidInstanceURL
        }

        return sanitized
    }
}

func fallbackProfileURL(baseURLString: String?, userName: String?) -> String? {
    guard let baseURLString = baseURLString?.nilIfEmpty,
          let cleanedUserName = userName?.trimmingPrefix("@").nilIfEmpty else {
        return nil
    }

    let normalizedBaseURL = baseURLString.replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
    return "\(normalizedBaseURL)/@\(cleanedUserName)"
}
