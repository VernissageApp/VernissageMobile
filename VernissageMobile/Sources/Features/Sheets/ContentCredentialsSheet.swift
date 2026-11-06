//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ContentCredentialsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let credentials: ContentCredentials

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppConstants.ContentCredentials.spacing) {
                    ContentCredentialsSummaryView(credentials: credentials, detailed: true)
                    ContentCredentialsValidationErrorsView(errors: credentials.validationErrors)
                    Divider()
                    ContentCredentialsDetailsView(credentials: credentials)

                    Link(destination: credentials.verifyURL) {
                        Label("Open on Verify Site", systemImage: "arrow.up.right.square")
                            .frame(maxWidth: .infinity, minHeight: AppConstants.ContentCredentials.minimumTapSize)
                    }
                    .buttonStyle(.glass)
                    .padding(.top, AppConstants.ContentCredentials.spacing)
                }
                .textSelection(.enabled)
                .padding(AppConstants.ContentCredentials.padding)
            }
            .navigationTitle(AppConstants.ContentCredentials.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close", action: close)
                }
            }
        }
    }

    private func close() {
        dismiss()
    }
}
