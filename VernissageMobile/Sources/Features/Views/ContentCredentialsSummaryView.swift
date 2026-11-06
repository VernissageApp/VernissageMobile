//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ContentCredentialsSummaryView: View {
    let credentials: ContentCredentials
    var detailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppConstants.ContentCredentials.spacing) {
            if detailed || credentials.verificationStatus != .untrusted {
                Label {
                    Text(credentials.verificationStatus.label)
                } icon: {
                    if credentials.verificationStatus == .invalid || credentials.verificationStatus == .unknown {
                        Image(systemName: credentials.verificationStatus.symbol)
                    } else {
                        ContentCredentialsIconView()
                    }
                }
                .font(.subheadline)
                .bold()
                .foregroundStyle(credentials.verificationStatus == .invalid ? Color.orange : Color.primary)
            }

            if !credentials.verificationStatus.hasValidIntegrity {
                Text(AppConstants.ContentCredentials.unverifiedMetadata)
                    .foregroundStyle(.secondary)

                if detailed {
                    Text(AppConstants.ContentCredentials.validationCaution)
                        .foregroundStyle(.secondary)
                }
            } else if detailed {
                Text(AppConstants.ContentCredentials.verifiedSummary)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
