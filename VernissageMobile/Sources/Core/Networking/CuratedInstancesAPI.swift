//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

enum CuratedInstancesAPI {
    private static let curatedInstancesURL = URL(string: "https://raw.githubusercontent.com/VernissageApp/Curated/refs/heads/main/instances.json")!

    static func fetchInstances() async throws -> [CuratedInstance] {
        var request = URLRequest(url: curatedInstancesURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw APIError.http(statusCode: httpResponse.statusCode, body: bodyText)
        }

        do {
            return try APIClient.jsonDecoder.decode([CuratedInstance].self, from: data)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }
}
