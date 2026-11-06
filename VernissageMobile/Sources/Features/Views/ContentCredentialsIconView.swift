//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ContentCredentialsIconView: View {
    @ScaledMetric(relativeTo: .headline) private var size = 24

    var body: some View {
        Image(.contentCredentials)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
