//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

enum APIClient {
    static func requestJSON<T: Decodable>(
        baseURL: URL,
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: Data? = nil,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
    ) async throws -> T {
        let request = try makeRequest(baseURL: baseURL,
                                      path: path,
                                      method: method,
                                      queryItems: queryItems,
                                      headers: headers,
                                      body: body,
                                      cachePolicy: cachePolicy)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw APIError.http(statusCode: httpResponse.statusCode, body: bodyText)
        }

        do {
            return try jsonDecoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }

    static func requestNoContent(
        baseURL: URL,
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: Data? = nil,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
    ) async throws {
        let request = try makeRequest(
            baseURL: baseURL,
            path: path,
            method: method,
            queryItems: queryItems,
            headers: headers,
            body: body,
            cachePolicy: cachePolicy
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw APIError.http(statusCode: httpResponse.statusCode, body: bodyText)
        }
    }

    private static func makeRequest(
        baseURL: URL,
        path: String,
        method: String,
        queryItems: [URLQueryItem],
        headers: [String: String],
        body: Data?,
        cachePolicy: URLRequest.CachePolicy
    ) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.timeoutInterval = 30
        request.cachePolicy = cachePolicy

        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        if headers["Accept"] == nil {
            request.setValue("application/json", forHTTPHeaderField: "Accept")
        }

        return request
    }

    static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()

            if let number = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: number)
            }

            if let string = try? container.decode(String.self) {
                if let number = Double(string) {
                    return Date(timeIntervalSince1970: number)
                }

                if let date = DateParser.parse(string) {
                    return date
                }
            }

            throw DecodingError.dataCorruptedError(in: container,
                                                   debugDescription: "Cannot decode date value.")
        }

        return decoder
    }()
}
