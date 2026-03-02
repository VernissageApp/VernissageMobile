//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI
import UIKit

struct AppSettingsScreen: View {
    @AppStorage(AppStorageKeys.settingsAlwaysShowNsfw) private var alwaysShowNsfw = false
    @AppStorage(AppStorageKeys.settingsShowAlternativeText) private var showAlternativeText = false
    @AppStorage(AppStorageKeys.settingsShowAvatarsOnTimeline) private var showAvatarsOnTimeline = false
    @AppStorage(AppStorageKeys.settingsShowImageCountsOnTimeline) private var showImageCountsOnTimeline = false
    @AppStorage(AppStorageKeys.settingsAppIconName) private var selectedAppIconName = AppIconOption.appIcon01.rawValue

    @State private var appIconErrorMessage: String?

    private enum AppIconOption: String, CaseIterable, Identifiable {
        case appIcon01 = "AppIcon01"
        case appIcon02 = "AppIcon02"

        var id: String { rawValue }

        var previewAssetName: String {
            "\(rawValue)Preview"
        }
    }
    
    private static let primaryAppIconName = AppIconOption.appIcon01.rawValue

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

            appIconSection
            
            otherSection
            socialSection
            versionSection
        }
        .navigationTitle("Preferences")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedAppIconName = currentAppIconName
        }
        .errorAlertToast($appIconErrorMessage)
    }

    @ViewBuilder
    private var appIconSection: some View {
        Section("Application icon") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(AppIconOption.allCases) { iconOption in
                        Button {
                            selectedAppIconName = iconOption.rawValue
                            applyAppIconSelection(iconOption.rawValue)
                        } label: {
                            appIconPreview(for: iconOption)
                                .frame(width: 90)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private func appIconPreview(for iconOption: AppIconOption) -> some View {
        ZStack(alignment: .topTrailing) {
            if let image = UIImage(named: iconOption.previewAssetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.secondary.opacity(0.12))
            }

            if selectedAppIconName == iconOption.rawValue {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue, .white)
                    .font(.system(size: 18))
                    .padding(4)
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(selectedAppIconName == iconOption.rawValue ? .blue : .secondary.opacity(0.22), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var otherSection: some View {
        Section("Other") {
            NavigationLink {
                ThirdPartyScreen()
            } label: {
                Text("Third party")
            }

            Link(destination: URL(string: "https://mczachurski.dev/vernissage-ios/privacy-policy.html")!) {
                Label("Privacy policy", systemImage: "hand.raised.square")
            }

            Link(destination: URL(string: "https://mczachurski.dev/vernissage-ios/terms.html")!) {
                Label("Terms of service", systemImage: "doc.text")
            }

            Link(destination: URL(string: "https://apps.apple.com/app/id6759335335?action=write-review")!) {
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

            NavigationLink {
                UserProfileScreen(
                    userName: "mczachurski@vernissage.photos",
                    preferredDisplayName: "Marcin Czachurski"
                )
            } label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Follow me", comment: "Follow me")
                        Text("Vernissage account", comment: "Vernissage account")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                    Text("@mczachurski")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
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
        Bundle.main.appVersionLabel
    }

    private var currentAppIconName: String {
        UIApplication.shared.alternateIconName ?? Self.primaryAppIconName
    }

    private func applyAppIconSelection(_ iconName: String) {
        guard UIApplication.shared.supportsAlternateIcons else {
            appIconErrorMessage = "Application icon switching is not supported on this device."
            return
        }

        let targetIconName = iconName == Self.primaryAppIconName ? nil : iconName
        guard UIApplication.shared.alternateIconName != targetIconName else {
            return
        }

        let previousSelection = currentAppIconName
        UIApplication.shared.setAlternateIconName(targetIconName) { error in
            guard let error else {
                return
            }

            Task { @MainActor in
                selectedAppIconName = previousSelection
                appIconErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}
