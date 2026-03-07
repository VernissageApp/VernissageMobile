//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation
import Photos

enum RemoteImageLibrarySaver {
    static func saveImage(from imageURL: URL) async throws {
        let authorizationStatus = await requestPhotoLibraryAuthorization()
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            throw SaveRemoteImageError.photoLibraryAccessRequired
        }

        let (data, response) = try await URLSession.shared.data(from: imageURL)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              data.isEmpty == false else {
            throw SaveRemoteImageError.downloadFailed
        }

        try await saveImageDataToPhotoLibrary(data)
    }

    private static func requestPhotoLibraryAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }
    }

    private static func saveImageDataToPhotoLibrary(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .photo, data: data, options: nil)
            }) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: SaveRemoteImageError.saveFailed)
                }
            }
        }
    }
}

private enum SaveRemoteImageError: LocalizedError {
    case photoLibraryAccessRequired
    case downloadFailed
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .photoLibraryAccessRequired:
            "Photo Library access is required to save images."
        case .downloadFailed:
            "Unable to download the image."
        case .saveFailed:
            "Unable to save the image to your photo library."
        }
    }
}
