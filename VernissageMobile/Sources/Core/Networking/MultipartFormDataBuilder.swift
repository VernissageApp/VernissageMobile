//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

enum MultipartFormDataBuilder {
    static func buildSingleFileBody(
        boundary: String,
        fieldName: String,
        fileName: String,
        mimeType: String,
        fileData: Data
    ) -> Data {
        var body = Data()
        body.appendUtf8("--\(boundary)\r\n")
        body.appendUtf8("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n")
        body.appendUtf8("Content-Type: \(mimeType)\r\n\r\n")
        body.append(fileData)
        body.appendUtf8("\r\n")
        body.appendUtf8("--\(boundary)--\r\n")
        return body
    }
}
