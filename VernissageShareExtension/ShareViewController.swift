//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import UIKit
import SwiftUI
import UniformTypeIdentifiers
import ImageIO

final class ShareViewController: UIViewController {
    private let composeSession = ShareComposeSession()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        presentCompose()

        Task {
            await prepareSharedAttachments()
        }
    }

    private func prepareSharedAttachments() async {
        do {
            let urls = try await prepareAttachmentURLs()
            await MainActor.run {
                composeSession.attachmentURLs = urls
                composeSession.isPreparingAttachments = false
            }
        } catch {
            await MainActor.run {
                composeSession.preparationErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                composeSession.isPreparingAttachments = false
            }
        }
    }

    private func prepareAttachmentURLs() async throws -> [URL] {
        let providers = imageProviders()
        guard providers.isEmpty == false else {
            return []
        }

        let temporaryDirectory = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("share-compose-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)

        var urls: [URL] = []

        for provider in providers {
            if let savedURL = try await saveImage(from: provider, directoryURL: temporaryDirectory) {
                urls.append(savedURL)
            }
        }

        return urls
    }

    private func imageProviders() -> [NSItemProvider] {
        let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []

        return items
            .flatMap { $0.attachments ?? [] }
            .filter { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }
    }

    private func saveImage(from provider: NSItemProvider, directoryURL: URL) async throws -> URL? {
        if let fileURL = await saveImageUsingFileRepresentation(from: provider, directoryURL: directoryURL) {
            return fileURL
        }

        guard let imageData = try await loadImageData(from: provider) else {
            return nil
        }

        let fileExtension = imageFileExtension(from: imageData) ?? AppConstants.MediaUpload.jpegFileExtension
        let fileName = "shared-\(UUID().uuidString).\(fileExtension)"
        let destinationURL = directoryURL.appendingPathComponent(fileName)
        try imageData.write(to: destinationURL, options: .atomic)

        return destinationURL
    }

    private func saveImageUsingFileRepresentation(from provider: NSItemProvider, directoryURL: URL) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { temporaryURL, error in
                if error != nil {
                    continuation.resume(returning: nil)
                    return
                }

                guard let temporaryURL else {
                    continuation.resume(returning: nil)
                    return
                }

                do {
                    let preferredExtension = temporaryURL.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines)
                    let fileExtension = preferredExtension.isEmpty ? "jpg" : preferredExtension
                    let fileName = "shared-\(UUID().uuidString).\(fileExtension)"
                    let destinationURL = directoryURL.appendingPathComponent(fileName)
                    try FileManager.default.copyItem(at: temporaryURL, to: destinationURL)
                    continuation.resume(returning: destinationURL)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func loadImageData(from provider: NSItemProvider) async throws -> Data? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: data)
            }
        }
    }

    private func imageFileExtension(from data: Data) -> String? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let typeIdentifier = CGImageSourceGetType(source) as String?,
              let type = UTType(typeIdentifier) else {
            return nil
        }

        return type.preferredFilenameExtension
    }

    private func presentCompose() {
        let rootView = ShareComposeRootView(
            session: composeSession,
            onClose: { [weak self] in
                self?.completeRequest()
            }
        )
        let hostingController = UIHostingController(rootView: rootView)

        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingController.view)

        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        hostingController.didMove(toParent: self)
    }

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
