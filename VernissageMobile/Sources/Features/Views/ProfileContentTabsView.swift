//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ProfileContentTabsView: View {
    @Binding var selectedTab: ProfileContentTab

    var body: some View {
        Picker("Profile content", selection: $selectedTab) {
            Text("Photos").tag(ProfileContentTab.photos)
            Text("Following").tag(ProfileContentTab.following)
            Text("Followers").tag(ProfileContentTab.followers)
        }
        .pickerStyle(.segmented)
    }

    private func countLabel(_ text: String, isActive: Bool) -> some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(isActive ? .primary : .secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}
