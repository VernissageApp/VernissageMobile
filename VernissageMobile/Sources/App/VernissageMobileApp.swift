//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI
import Nuke

@main
struct VernissageMobileApp: App {
    @StateObject private var appState = AppState()

    private static let imagePipelineCacheName = "photos.vernissage.vernissage.data-cache"
    private static let imagePipelineCacheSizeLimit = 300 * 1024 * 1024

    private static let imagePipelineConfigurationToken: Void = {
        let dataLoaderConfiguration = DataLoader.defaultConfiguration
        dataLoaderConfiguration.urlCache = nil

        let pipeline = ImagePipeline {
            $0.dataLoader = DataLoader(configuration: dataLoaderConfiguration)
            $0.imageCache = ImageCache.shared

            if let dataCache = try? DataCache(name: imagePipelineCacheName) {
                dataCache.sizeLimit = imagePipelineCacheSizeLimit
                $0.dataCache = dataCache
            }
        }

        ImagePipeline.shared = pipeline
    }()

    init() {
        Self.configureImagePipelineIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootScreen()
                .environmentObject(appState)
        }
    }

    private static func configureImagePipelineIfNeeded() {
        _ = imagePipelineConfigurationToken
    }
}
