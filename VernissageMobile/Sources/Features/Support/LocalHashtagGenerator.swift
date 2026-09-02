//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import FoundationModels
import UIKit

struct LocalHashtagGenerator {
    private static let hashtagCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "#_"))

#if canImport(FoundationModels, _version: 2.0)
    static var isAvailable: Bool {
        guard #available(iOS 27.0, *) else {
            return false
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            return false
        }

        return model.capabilities.contains(.vision)
    }

    static func generate(
        images: [UIImage],
        altTexts: [String],
        statusText: String
    ) async throws -> [String] {
        guard #available(iOS 27.0, *), !images.isEmpty else {
            return []
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability,
              model.capabilities.contains(.vision) else {
            return []
        }

        try Task.checkCancellation()

        let normalizedStatusText = statusText.trimmingCharacters(in: .whitespacesAndNewlines)
        let session = LanguageModelSession(model: model)
        let response = try await session.respond(
            generating: LocalHashtagSuggestionResponse.self,
            options: GenerationOptions(samplingMode: .greedy, maximumResponseTokens: 200)
        ) {
            """
            Generate up to \(AppConstants.LocalModel.maximumHashtagCount) short hashtag concepts for the provided images. The visible image content is the \
            source of truth. Every concept must be directly and clearly supported by something visible in the images. Prefer \
            concrete subjects, places, objects, activities, and setting details for the specific concepts.

            Also select broad visual classifications using these rules:
            - For one image, select exactly one color treatment: color photography when meaningful color is visibly present, or \
              black and white only when the image has no meaningful color. Never select both for the same image.
            - For multiple images, select either or both color treatments only when the attached images genuinely contain them.
            - Select no more than two photographic genres or subject categories, and only when the main subject and composition \
              clearly match them.
            - Select portrait only when a person is the primary subject of the composition.
            - Select architecture only when a building, structure, or architectural detail is a primary visual subject.
            - Select landscape only for a broad scene in which the environment is the primary subject. Landscape does not mean \
              horizontal image orientation.
            - Select street photography only when an observed public-space scene or street life is a central subject.
            - Do not select any classification merely because its name appears in the available list. If its visual criteria are \
              not satisfied, omit it.

            If a specific concept is uncertain, omit it instead of guessing. Do not add generic engagement terms and do not \
            mention any existing social network. The ALT text and status text are secondary context: use them only when they \
            agree with the visible content, and never let them introduce a visual attribute that is not evident in the image. \
            Return specific concepts as plain phrases with spaces between words, without a # character, punctuation, camel case, \
            or all-uppercase text. Do not repeat concepts already present as hashtags in the status text.
            """

            if !normalizedStatusText.isEmpty {
                "Status text: \(normalizedStatusText)"
            }

            for index in images.indices {
                let normalizedAltText = altTexts.indices.contains(index)
                    ? altTexts[index].trimmingCharacters(in: .whitespacesAndNewlines)
                    : ""

                "ALT text for image \(index + 1): \(normalizedAltText.nilIfEmpty ?? "Not provided.")"
                FoundationModels.Attachment(images[index]).label("Image \(index + 1)")
            }
        }

        try Task.checkCancellation()
        return makeHashtags(
            from: response.content.specificPhrases + response.content.generalPhrases
        )
    }
#else
    static var isAvailable: Bool {
        false
    }

    static func generate(
        images _: [UIImage],
        altTexts _: [String],
        statusText _: String
    ) async throws -> [String] {
        []
    }
#endif

    static func extractHashtags(from text: String, limit: Int? = nil) -> [String] {
        let components = text.components(separatedBy: hashtagCharacterSet.inverted)
        var normalizedHashtags: [String] = []
        var seenHashtags: Set<String> = []

        for component in components {
            guard component.hasPrefix("#"), component.count > 1 else {
                continue
            }

            let normalizedValue = component.lowercased()
            guard seenHashtags.insert(normalizedValue).inserted else {
                continue
            }

            normalizedHashtags.append(component)
            if let limit, normalizedHashtags.count >= limit {
                break
            }
        }

        return normalizedHashtags
    }

    private static func makeHashtags(from phrases: [String]) -> [String] {
        var hashtags: [String] = []
        var seenHashtags: Set<String> = []

        for phrase in phrases {
            guard let hashtag = makePascalCaseHashtag(from: phrase) else {
                continue
            }

            guard seenHashtags.insert(hashtag.lowercased()).inserted else {
                continue
            }

            hashtags.append(hashtag)
            if hashtags.count >= AppConstants.LocalModel.maximumHashtagCount {
                break
            }
        }

        return hashtags
    }

    private static func makePascalCaseHashtag(from phrase: String) -> String? {
        let phraseWithoutHash = phrase.trimmingCharacters(in: .whitespacesAndNewlines).trimmingPrefix("#")
        let components = phraseWithoutHash.components(separatedBy: CharacterSet.alphanumerics.inverted)
        let words = components
            .filter { !$0.isEmpty }
            .flatMap(splitCamelCaseWords)

        let pascalCaseValue = words.map { word in
            let lowercaseWord = word.lowercased()
            return lowercaseWord.prefix(1).uppercased() + String(lowercaseWord.dropFirst())
        }
        .joined()

        guard !pascalCaseValue.isEmpty else {
            return nil
        }

        return "#\(pascalCaseValue)"
    }

    private static func splitCamelCaseWords(_ value: String) -> [String] {
        var words: [String] = []
        var currentWord = ""

        for character in value {
            if character.isUppercase, currentWord.last?.isLowercase == true {
                words.append(currentWord)
                currentWord = String(character)
            } else {
                currentWord.append(character)
            }
        }

        if !currentWord.isEmpty {
            words.append(currentWord)
        }

        return words
    }
}
