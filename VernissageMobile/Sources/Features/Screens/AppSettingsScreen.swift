//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct AppSettingsScreen: View {
    @AppStorage("settings.alwaysShowNsfw") private var alwaysShowNsfw = false
    @AppStorage("settings.showAlternativeText") private var showAlternativeText = false
    @AppStorage("settings.showAvatarsOnTimeline") private var showAvatarsOnTimeline = false
    @AppStorage("settings.showImageCountsOnTimeline") private var showImageCountsOnTimeline = false

    var body: some View {
        List {
            Section("Media settings") {
                Toggle(isOn: $alwaysShowNsfw) {
                    VStack(alignment: .leading) {
                        Text("Always show NSFW", comment: "Always show NSFW")
                        Text("Force show all NFSW (sensitive) media without warnings.", comment: "Force show all NFSW (sensitive) media without warnings.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Toggle(isOn: $showAlternativeText) {
                    VStack(alignment: .leading) {
                        Text("Show alternative text", comment: "Show alternative text")
                        Text("Show alternative text if present on status details screen.", comment: "Show alternative text if present on status details screen.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Toggle(isOn: $showAvatarsOnTimeline) {
                    VStack(alignment: .leading) {
                        Text("Show avatars", comment: "Show avatars")
                        Text("Show avatars on timeline.", comment: "Show avatars on timeline.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: $showImageCountsOnTimeline) {
                    VStack(alignment: .leading) {
                        Text("Show image counts")
                        Text("Show image count on statuses with multiple images.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            otherSection
            socialSection
            versionSection
        }
        .navigationTitle("Preferences")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ViewBuilder
    private var otherSection: some View {
        Section("Other") {
            NavigationLink {
                ThirdPartyScreen()
            } label: {
                Text("Third party")
            }

            Link(destination: URL(string: "https://mczachurski.dev/vernissage/privacy-policy.html")!) {
                Label("Privacy policy", systemImage: "hand.raised.square")
            }

            Link(destination: URL(string: "https://mczachurski.dev/vernissage/terms.html")!) {
                Label("Terms of service", systemImage: "doc.text")
            }

            Link(destination: URL(string: "https://apps.apple.com/app/id1663543216?action=write-review")!) {
                Label("Rate the app", systemImage: "star")
            }

            Link(destination: URL(string: "https://github.com/VernissageApp/VernissageMobile")!) {
                Label("Source code", systemImage: "swift")
            }

            Link(destination: URL(string: "https://github.com/VernissageApp/VernissageMobile/issues")!) {
                Label("Report a bug", systemImage: "ant")
            }
        }
    }
    
    @ViewBuilder
    private var socialSection: some View {
        Section("Socials") {
            HStack {
                VStack(alignment: .leading) {
                    Text("Follow Vernissage", comment: "Follow Vernissage")
                    Text("Mastodon account", comment: "Mastodon account")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                Link("@vernissage", destination: URL(string: "https://mastodon.social/@vernissage")!)
                    .font(.footnote)
            }

            HStack {
                VStack(alignment: .leading) {
                    Text("Follow me", comment: "Follow me")
                    Text("Mastodon account", comment: "Mastodon account")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                Link("@mczachurski", destination: URL(string: "https://mastodon.social/@mczachurski")!)
                    .font(.footnote)
            }

            HStack {
                VStack(alignment: .leading) {
                    Text("Follow me", comment: "Follow me")
                    Text("Vernissage account", comment: "Vernissage account")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                Link("@mczachurski", destination: URL(string: "https://vernissage.photos/@mczachurski")!)
                    .font(.footnote)
            }
        }
    }
    
    @ViewBuilder
    private var versionSection: some View {
        Section {
            HStack {
                Text("Version", comment: "Version")
                Spacer()
                Text(appVersionLabel)
            }
        }
    }
    
    private var appVersionLabel: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (shortVersion?.nilIfEmpty, buildVersion?.nilIfEmpty) {
        case let (.some(short), .some(build)):
            return "\(short) (\(build))"
        case let (.some(short), .none):
            return short
        case let (.none, .some(build)):
            return build
        default:
            return "Unknown"
        }
    }
}
