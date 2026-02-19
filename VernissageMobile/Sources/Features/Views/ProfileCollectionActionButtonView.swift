//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ProfileCollectionActionButtonView: View {
    let systemImage: String

    var body: some View {
        Capsule(style: .continuous)
            .fill(.clear)
            .overlay(
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.blue)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color(uiColor: .separator).opacity(0.55), lineWidth: 1)
            )
            .frame(maxWidth: .infinity, minHeight: 52)
    }
}
