//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ProfileOverviewSkeletonCardView: View {
    let showCollectionsActions: Bool

    var body: some View {
        VStack(spacing: 16) {
            Circle()
                .fill(Color(uiColor: .secondarySystemFill))
                .frame(width: 140, height: 140)

            VStack(spacing: 8) {
                Text("Display Name")
                    .font(.title.weight(.bold))
                Text("@username")
                    .font(.headline.weight(.semibold))
            }

            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemFill))
                    .frame(height: 18)
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemFill))
                    .frame(width: 220, height: 18)
            }

            HStack(spacing: 18) {
                ProfileMetricView(title: "Photos", value: 000)
                ProfileMetricView(title: "Followers", value: 000)
                ProfileMetricView(title: "Following", value: 000)
            }
            .padding(.top, 4)
            .padding(.horizontal, 8)

            if showCollectionsActions {
                HStack(spacing: 12) {
                    ProfileCollectionActionButtonView(systemImage: "star.fill")
                    ProfileCollectionActionButtonView(systemImage: "bookmark.fill")
                    ProfileCollectionActionButtonView(systemImage: "qrcode")
                }
                .padding(.horizontal, 8)
            }
        }
    }
}
