//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ProfileLoadingSkeletonView: View {
    let showCollectionsActions: Bool

    var body: some View {
        LazyVStack(spacing: 16) {
            ProfileOverviewSkeletonCardView(showCollectionsActions: showCollectionsActions)
                .padding(.horizontal, 16)

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(uiColor: .secondarySystemFill))
                .frame(height: 32)
                .padding(.horizontal, 16)

            LazyVStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemFill))
                        .frame(height: 220)
                }
            }
            .padding(.horizontal, 16)
        }
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
    }
}
