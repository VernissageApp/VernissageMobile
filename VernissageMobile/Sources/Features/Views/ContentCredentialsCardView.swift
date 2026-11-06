//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ContentCredentialsCardView: View {
    let credentials: ContentCredentials
    let onDetails: () -> Void

    private var borderColor: Color {
        switch credentials.verificationStatus {
        case .verified, .untrusted:
            .green
        case .invalid:
            .orange
        case .unknown:
            .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppConstants.ContentCredentials.spacing) {
            HStack {
                Label {
                    Text(AppConstants.ContentCredentials.title)
                } icon: {
                    ContentCredentialsIconView()
                }
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Button("Content Credentials details", systemImage: "info.circle", action: onDetails)
                    .labelStyle(.iconOnly)
                    .frame(
                        minWidth: AppConstants.ContentCredentials.minimumTapSize,
                        minHeight: AppConstants.ContentCredentials.minimumTapSize
                    )
                    .buttonStyle(.plain)
            }

            if credentials.verificationStatus != .untrusted {
                ContentCredentialsSummaryView(credentials: credentials)
            }
            ContentCredentialsFieldView(title: "Author", value: credentials.author ?? credentials.signatureIssuer)
            ContentCredentialsFieldView(
                title: AppConstants.ContentCredentials.appOrDeviceUsed,
                value: credentials.appOrDeviceUsed
            )
            ContentCredentialsFieldView(
                title: "Equipment/Application",
                value: credentials.softwareAgent ?? credentials.claimGenerator
            )

            if credentials.verificationStatus == .untrusted {
                Text(credentials.verificationStatus.label)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if credentials.aiGenerated && credentials.verificationStatus.hasValidIntegrity {
                Divider()
                Label("AI Generated", systemImage: "sparkles")
                    .font(.subheadline)
            }
        }
        .padding(AppConstants.ContentCredentials.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassCard()
        .overlay {
            RoundedRectangle(cornerRadius: AppConstants.ContentCredentials.cornerRadius)
                .strokeBorder(borderColor, lineWidth: 1)
        }
    }
}
