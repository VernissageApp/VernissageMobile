//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ThirdPartyScreen: View {
    var body: some View {
        List {
            Section("EmojiText") {
                VStack(alignment: .leading) {
                    Link("thirdparty.customemoji.address",
                         destination: URL(string: "https://github.com/divadretlaw/EmojiText")!)
                    .padding(.bottom, 4)
                    Text("Render Custom Emoji in Text.", comment: "Render Custom Emoji in Text.")
                }
                .font(.footnote)
            }

            Section("HTML2Markdown") {
                VStack(alignment: .leading) {
                    Link("thirdparty.htmlmarkdown.address",
                         destination: URL(string: "https://gitlab.com/mflint/HTML2Markdown")!)
                    .padding(.bottom, 4)
                    Text("It's a Swift Package which attempts to convert HTML into Markdown.", comment: "It's a Swift Package which attempts to convert HTML into Markdown.")
                }
                .font(.footnote)
            }

            Section("AlertToast") {
                VStack(alignment: .leading) {
                    Link("thirdparty.oauth.address",
                         destination: URL(string: "https://github.com/elai950/AlertToast")!)
                    .padding(.bottom, 4)
                    Text("Present Apple-like alert & toast in SwiftUI.", comment: "Present Apple-like alert & toast in SwiftUI.")
                }
                .font(.footnote)
            }
        }
        .navigationTitle("Third party")
        .navigationBarTitleDisplayMode(.inline)
    }
}
