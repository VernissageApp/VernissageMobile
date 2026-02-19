//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI
import HTML2Markdown

extension String {
    var strippedHTML: String {
        replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var withProfileSoftBreaks: String {
        self
            .replacingOccurrences(of: "/", with: "/\u{200B}")
            .replacingOccurrences(of: "#", with: "#\u{200B}")
            .replacingOccurrences(of: "-", with: "-\u{200B}")
            .replacingOccurrences(of: "_", with: "_\u{200B}")
            .replacingOccurrences(of: "?", with: "?\u{200B}")
            .replacingOccurrences(of: "&", with: "&\u{200B}")
            .replacingOccurrences(of: "=", with: "=\u{200B}")
            .replacingOccurrences(of: ".", with: ".\u{200B}")
            .replacingOccurrences(of: ":", with: ":\u{200B}")
            .breakingLongRuns(every: 14)
    }

    func breakingLongRuns(every chunkSize: Int) -> String {
        guard chunkSize > 1 else {
            return self
        }

        var result = ""
        var currentRunLength = 0

        for character in self {
            result.append(character)

            if character.isWhitespace || character == "\u{200B}" {
                currentRunLength = 0
                continue
            }

            currentRunLength += 1
            if currentRunLength >= chunkSize {
                result.append("\u{200B}")
                currentRunLength = 0
            }
        }

        return result
    }
}
extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func trimmingPrefix(_ prefix: String) -> String {
        guard hasPrefix(prefix) else {
            return self
        }

        return String(dropFirst(prefix.count))
    }

    var decodingHTMLEntities: String {
        guard let data = data(using: .utf8),
              let decoded = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
              ) else {
            return self
        }

        return decoded.string
    }

    var normalizedDecimalCoordinate: String? {
        let normalized = replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let number = Double(normalized) else {
            return nil
        }

        return String(number)
    }

    var normalizedLatitudeCoordinate: String? {
        normalizedSignedCoordinate(positiveSuffix: "N", negativeSuffix: "S")
    }

    var normalizedLongitudeCoordinate: String? {
        normalizedSignedCoordinate(positiveSuffix: "E", negativeSuffix: "W")
    }

    private func normalizedSignedCoordinate(positiveSuffix: Character, negativeSuffix: Character) -> String? {
        var value = replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        if value.hasSuffix(String(negativeSuffix)) {
            value = String(value.dropLast())
            if !value.hasPrefix("-") {
                value = "-\(value)"
            }
        } else if value.hasSuffix(String(positiveSuffix)) {
            value = String(value.dropLast())
        }

        guard let number = Double(value) else {
            return nil
        }

        return String(number)
    }
    
    func parseToMarkdown() throws -> String {
        let mutatedHtml = self
            // Fix issue: https://github.com/VernissageApp/Home/issues/11
            // First we have to replace <br />/n into single <br /> (new line is skipped by HTML but this causes empty space in HTML2Markdown.
            .replacingOccurrences(of: "<br />\n", with: "<br />")
            .replacingOccurrences(of: "<br/>\n", with: "<br />")
            // Fix issue: https://github.com/VernissageApp/Home/issues/10
            // When we replace all <br />\n into single <br /> then we have to change the remaining \n into <br />
            .replacingOccurrences(of: "\n", with: "<br />")

        let dom = try HTMLParser().parse(html: mutatedHtml)
        return dom.toMarkdown()
            // Add space between hashtags and mentions that follow each other
            .replacingOccurrences(of: ")[", with: ") [")
    }
}
extension String {
    var toastPresentableMessage: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        guard !trimmed.isCancellationLikeMessage else {
            return nil
        }

        return trimmed
    }

    var isCancellationLikeMessage: Bool {
        let normalized = trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else {
            return false
        }

        if normalized == "cancelled" || normalized == "canceled" {
            return true
        }

        if normalized.contains("nsurlerrordomain") && normalized.contains("-999") {
            return true
        }

        if normalized.contains("urlerror.cancelled") {
            return true
        }

        return false
    }
}
extension String {
    func decode83() -> Int {
        var value: Int = 0
        for character in self {
            if let digit = decodeCharacters[String(character)] {
                value = value * 83 + digit
            }
        }
        return value
    }
}

private let encodeCharacters: [String] = {
    "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz#$%*+,-.:;=?@[]^_{|}~".map { String($0) }
}()

private let decodeCharacters: [String: Int] = {
    var dict: [String: Int] = [:]
    for (index, character) in encodeCharacters.enumerated() {
        dict[character] = index
    }
    return dict
}()
extension String {
    subscript (offset: Int) -> Character {
        return self[index(startIndex, offsetBy: offset)]
    }

    subscript (bounds: CountableClosedRange<Int>) -> Substring {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return self[start...end]
    }

    subscript (bounds: CountableRange<Int>) -> Substring {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return self[start..<end]
    }
}
