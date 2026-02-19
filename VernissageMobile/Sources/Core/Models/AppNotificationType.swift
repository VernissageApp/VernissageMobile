//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

enum AppNotificationType: String {
    case mention
    case status
    case reblog
    case follow
    case followRequest
    case favourite
    case update
    case adminSignUp
    case adminReport
    case newComment
}
