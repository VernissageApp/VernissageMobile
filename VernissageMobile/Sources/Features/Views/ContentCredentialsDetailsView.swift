//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ContentCredentialsDetailsView: View {
    let credentials: ContentCredentials

    var body: some View {
        VStack(alignment: .leading, spacing: AppConstants.ContentCredentials.spacing) {
            ContentCredentialsFieldView(
                title: credentials.identityVerificationWarning == nil ? "Identity" : "Unverified identity",
                value: credentials.identity
            )
            ContentCredentialsFieldView(
                title: AppConstants.ContentCredentials.appOrDeviceUsed,
                value: credentials.appOrDeviceUsed
            )
            ContentCredentialsFieldView(title: "Format", value: credentials.format)
            ContentCredentialsFieldView(title: "Produced with", value: credentials.claimGenerator)
            ContentCredentialsFieldView(title: "Signed by", value: credentials.signatureIssuer)
            ContentCredentialsFieldView(
                title: AppConstants.ContentCredentials.signedAt,
                value: credentials.signedAt?.formatted(.dateTime.day().month().year().hour().minute().second())
                    ?? credentials.signatureTime
            )
            ContentCredentialsFieldView(title: "Actions", value: credentials.actions)
        }
    }
}
