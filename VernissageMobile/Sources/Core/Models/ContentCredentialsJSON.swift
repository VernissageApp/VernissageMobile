//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

/// Preserves arbitrary assertion payloads without passing untyped objects across actors.
indirect enum ContentCredentialsJSON: Decodable, Sendable {
    case object([String: Self])
    case array([Self])
    case string(String)
    case number(Double)
    case boolean(Bool)
    case null

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode([String: Self].self) {
            self = .object(value)
        } else {
            self = .array(try container.decode([Self].self))
        }
    }

    subscript(key: String) -> Self? {
        guard case let .object(value) = self else {
            return nil
        }

        return value[key]
    }

    var array: [Self] {
        guard case let .array(value) = self else {
            return []
        }

        return value
    }

    var object: [String: Self] {
        guard case let .object(value) = self else {
            return [:]
        }

        return value
    }

    var string: String? {
        guard case let .string(value) = self else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var bool: Bool? {
        guard case let .boolean(value) = self else {
            return nil
        }

        return value
    }

    /// Matches the web client's handling of schema.org names, arrays and identifiers.
    var displayString: String? {
        if let string {
            return string
        }

        if case let .array(values) = self {
            return values.lazy.compactMap { $0.namedValue }.first
        }

        return namedValue
    }

    private var namedValue: String? {
        self["name"]?.displayString
            ?? self["@name"]?.displayString
            ?? self["identifier"]?.displayString
    }
}
