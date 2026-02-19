//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct FlexiField: Decodable {
    let id: String?
    let key: String?
    let value: String?
    let valueHtml: String?
    let isVerified: Bool?
}
extension FlexiField {
    var displayText: String? {
        if let value = value?.nilIfEmpty {
            return value.withProfileSoftBreaks
        }

        return valueHtml?.nilIfEmpty?.strippedHTML.withProfileSoftBreaks
    }
    
    var markdownText: String? {
        guard let value = value?.nilIfEmpty else {
            return nil
        }

        let markdown = try? value.parseToMarkdown()
        return markdown?.nilIfEmpty ?? value
    }
}
