//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ContentCredentialsValidationErrorsView: View {
    let errors: [ContentCredentialsValidationStatus]

    var body: some View {
        if !errors.isEmpty {
            VStack(alignment: .leading, spacing: AppConstants.ContentCredentials.spacing) {
                Text("Validation error details")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                ForEach(errors, id: \.self) { error in
                    VStack(alignment: .leading, spacing: AppConstants.ContentCredentials.spacing / 2) {
                        Text(error.message)

                        if let code = error.code {
                            Text(code)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
