//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import FoundationModels

#if canImport(FoundationModels, _version: 2.0)
@available(iOS 27.0, *)
@Generable
struct LocalHashtagSuggestionResponse {
    @Guide(
        description: "Specific subjects, places, objects, activities, and setting details that are clearly visible. Write each concept as a plain phrase with spaces between words. Do not include the # character, punctuation, camel case, or all-uppercase text.",
        .maximumCount(7)
    )
    var specificPhrases: [String]

    @Guide(
        description: "Broad visual classifications that are directly supported by the images. Select color treatment and photographic genres only when their visual criteria are satisfied.",
        .count(1...3),
        .element(
            .anyOf([
                "color photography",
                "black and white",
                "landscape",
                "architecture",
                "portrait",
                "street photography",
                "nature",
                "wildlife",
                "macro photography",
                "documentary photography",
                "still life",
                "abstract photography",
                "night photography",
                "travel photography"
            ])
        )
    )
    var generalPhrases: [String]
}
#endif
