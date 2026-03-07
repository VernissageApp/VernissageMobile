//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct SettingsToolbarButtonView: View {
    var body: some View {
        NavigationLink {
            AppSettingsScreen()
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .accessibilityLabel("Settings")
    }
}
