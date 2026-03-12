//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

@MainActor
final class AttachmentsAPI {
    private unowned let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func uploadAttachment(imageData: Data, fileName: String, mimeType: String) async throws -> UploadedAttachment {
        let account = try appState.requireActiveAccount()

        let boundary = "Boundary-\(UUID().uuidString)"
        let requestBody = MultipartFormDataBuilder.buildSingleFileBody(
            boundary: boundary,
            fieldName: "file",
            fileName: fileName,
            mimeType: mimeType,
            fileData: imageData
        )

        return try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/attachments",
            method: "POST",
            queryItems: [],
            additionalHeaders: ["Content-Type": "multipart/form-data; boundary=\(boundary)"],
            body: requestBody
        )
    }

    func updateAttachment(attachmentId: String, request: AttachmentUpdateRequest) async throws {
        let account = try appState.requireActiveAccount()
        let encodedAttachmentId = attachmentId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? attachmentId

        try await appState.api.authorizedRequestNoContent(
            account: account,
            path: "/api/v1/attachments/\(encodedAttachmentId)",
            method: "PUT",
            queryItems: [],
            additionalHeaders: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(request)
        )
    }

    func deleteAttachment(attachmentId: String) async throws {
        let account = try appState.requireActiveAccount()
        let encodedAttachmentId = attachmentId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? attachmentId

        try await appState.api.authorizedRequestNoContent(
            account: account,
            path: "/api/v1/attachments/\(encodedAttachmentId)",
            method: "DELETE",
            queryItems: []
        )
    }

    func describeAttachment(attachmentId: String) async throws -> String? {
        let account = try appState.requireActiveAccount()
        let encodedAttachmentId = attachmentId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? attachmentId

        let response: AttachmentDescriptionResult = try await appState.api.authorizedRequest(
            account: account,
            path: "/api/v1/attachments/\(encodedAttachmentId)/describe",
            queryItems: []
        )

        return response.description?.nilIfEmpty
    }

}
