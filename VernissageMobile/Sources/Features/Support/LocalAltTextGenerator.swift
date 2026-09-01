//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import FoundationModels
import UIKit

struct LocalAltTextGenerator {
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

    static func generate(for image: UIImage) async throws -> String? {
        guard #available(iOS 27.0, *) else {
            return nil
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability,
              model.capabilities.contains(.vision) else {
            return nil
        }

        let session = LanguageModelSession(model: model)
        let response = try await session.respond {
            """
            Generate concise and clear alt text for an image by accurately describing its visual elements and composition. \
            Avoid expressing subjective feelings or interpretations. Ensure the alt text provides enough context for users \
            who rely on these descriptions to understand the image. Include significant details that visually impaired users \
            would find informative. Do not start sentences with introductions like "This image shows ..." or \
            "This is a picture of ...". Return only the alt text.
            """

            FoundationModels.Attachment(image)
        }

        return response.content.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }
}
