//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import C2PA
import Foundation
import UniformTypeIdentifiers

/// Downloads originals to disk and confines synchronous native verification to a background actor.
actor ContentCredentialsService {
    static let shared = ContentCredentialsService()

    private var cache: [URL: ContentCredentials] = [:]
    private var cachedURLs: [URL] = []

    func credentials(for imageURL: URL) async -> ContentCredentials? {
        guard !Task.isCancelled else {
            return nil
        }

        if let cached = cache[imageURL] {
            return cached
        }

        do {
            var request = URLRequest(url: imageURL, cachePolicy: .reloadIgnoringLocalCacheData)
            request.timeoutInterval = AppConstants.ContentCredentials.requestTimeout
            let (fileURL, response) = try await URLSession.shared.download(for: request)

            // Stream the original from disk and remove it on every exit path, including cancellation.
            defer {
                try? FileManager.default.removeItem(at: fileURL)
            }

            try Task.checkCancellation()

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  let format = try imageFormat(fileURL: fileURL, response: response, sourceURL: imageURL),
                  let credentials = try readCredentials(fileURL: fileURL, format: format, imageURL: imageURL) else {
                return nil
            }

            cacheCredentials(credentials, for: imageURL)
            return credentials
        } catch {
            // Like the web client, an absent/unreadable manifest leaves the optional panel hidden.
            return nil
        }
    }

    private func readCredentials(fileURL: URL, format: String, imageURL: URL) throws -> ContentCredentials? {
        let context = try makeVerificationContext()
        let stream = try Stream(readFrom: fileURL)
        let reader = try Reader(context: context, format: format, stream: stream)
        let json = try reader.json()
        try Task.checkCancellation()

        return try ContentCredentialsParser().parse(Data(json.utf8), imageURL: imageURL)
    }

    private func makeVerificationContext() throws -> C2PAContext {
        // Native contexts need the standard EKUs explicitly to match web validation of Sony ingredients.
        let definition = C2PASettingsDefinition(
            trust: TrustSettings(
                trustConfig: AppConstants.ContentCredentials.acceptedCertificateEKUs.joined(separator: "\n")
            ),
            verify: VerifySettings(verifyAfterReading: true, verifyTrust: true)
        )
        let settings = try C2PASettings(definition: definition)
        let deadline = Date.now.addingTimeInterval(AppConstants.ContentCredentials.verificationTimeout)

        // The synchronous SDK checks this callback during verification, allowing cancelled
        // screen tasks and verification deadlines to stop work at the next native checkpoint.
        return try C2PAContext(settings: settings, onProgress: { _ in
            Task.isCancelled || Date.now > deadline ? .cancel : .continue
        })
    }

    private func cacheCredentials(_ credentials: ContentCredentials, for imageURL: URL) {
        if cache[imageURL] == nil {
            cachedURLs.append(imageURL)
        }

        cache[imageURL] = credentials

        while cachedURLs.count > AppConstants.ContentCredentials.cacheLimit {
            let oldestURL = cachedURLs.removeFirst()
            cache.removeValue(forKey: oldestURL)
        }
    }

    private func imageFormat(fileURL: URL, response: URLResponse, sourceURL: URL) throws -> String? {
        let handle = try FileHandle(forReadingFrom: fileURL)

        defer {
            try? handle.close()
        }

        let bytes = [UInt8](try handle.read(upToCount: 32) ?? Data())

        // Some CDNs serve originals as application/octet-stream, so inspect the file first.
        if let format = imageFormatFromSignature(bytes) {
            return format
        }

        if let mimeType = response.mimeType, mimeType.hasPrefix("image/") {
            return mimeType == "image/jpg" ? AppConstants.MediaUpload.jpegMimeType : mimeType
        }

        return UTType(filenameExtension: sourceURL.pathExtension)?.preferredMIMEType
    }

    private func imageFormatFromSignature(_ bytes: [UInt8]) -> String? {
        if bytes.starts(with: [0xff, 0xd8, 0xff]) {
            return AppConstants.MediaUpload.jpegMimeType
        }

        if bytes.starts(with: [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]) {
            return "image/png"
        }

        if bytes.count >= 12,
           String(bytes: bytes[0..<4], encoding: .ascii) == "RIFF",
           String(bytes: bytes[8..<12], encoding: .ascii) == "WEBP" {
            return AppConstants.MediaUpload.webpMimeType
        }

        return nil
    }
}
