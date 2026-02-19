//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct MainTabScreen: View {
    private enum MainTab: Hashable {
        case privateHome
        case editors
        case trending
        case other
        case search
    }

    @EnvironmentObject private var appState: AppState
    @State private var showAccountSwitcher = false
    @State private var selectedTab: MainTab = .privateHome
    @State private var selectedOtherTimeline: OtherTimelineSelection = .local

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Private", systemImage: "person", value: .privateHome) {
                TimelineScreen(kind: .privateHome,
                               title: "Your timeline",
                               subtitle: "Your personal collection of photos, created based on posts from users you follow.",
                                showAccountSwitcher: $showAccountSwitcher)
            }

            Tab("Editors", systemImage: "star.circle", value: .editors) {
                EditorsScreen(showAccountSwitcher: $showAccountSwitcher)
            }

            Tab("Trending", systemImage: "flame.fill", value: .trending) {
                TrendingScreen(showAccountSwitcher: $showAccountSwitcher)
            }

            Tab("Timelines", systemImage: "photo.stack", value: .other) {
                OtherTimelineScreen(
                    selectedTimeline: $selectedOtherTimeline,
                    showAccountSwitcher: $showAccountSwitcher
                )
            }

            Tab("Search", systemImage: "magnifyingglass", value: .search, role: .search) {
                SearchScreen(showAccountSwitcher: $showAccountSwitcher)
            }
        }
        .sheet(isPresented: $showAccountSwitcher) {
            AccountSwitcherSheet()
                .environmentObject(appState)
        }
    }
}
