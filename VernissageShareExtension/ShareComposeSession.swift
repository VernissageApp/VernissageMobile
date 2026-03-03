//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation
import Combine

@MainActor
final class ShareComposeSession: ObservableObject {
    @Published var attachmentURLs: [URL] = []
    @Published var isPreparingAttachments = true
    @Published var preparationErrorMessage: String?
}
