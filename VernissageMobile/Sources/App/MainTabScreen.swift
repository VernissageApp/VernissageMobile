//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct MainTabScreen: View {
    @Environment(AppState.self) private var appState
    @State private var showAccountSwitcher = false
    @State private var selectedTab: MainTabSelection = .timelines
    @State private var selectedTimeline: TimelineSelection = .privateHome

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Timelines", systemImage: "photo.stack", value: .timelines) {
                TimelinesScreen(
                    selectedTimeline: $selectedTimeline,
                    showAccountSwitcher: $showAccountSwitcher
                )
            }

            Tab("Featured", systemImage: "star.circle", value: .editors) {
                EditorsScreen(showAccountSwitcher: $showAccountSwitcher)
            }

            Tab("Trending", systemImage: "flame.fill", value: .trending) {
                TrendingScreen(showAccountSwitcher: $showAccountSwitcher)
            }

            Tab("Explore", systemImage: "safari.fill", value: .explore) {
                ExploreScreen(showAccountSwitcher: $showAccountSwitcher)
            }

            Tab("Search", systemImage: "magnifyingglass", value: .search, role: .search) {
                SearchScreen(showAccountSwitcher: $showAccountSwitcher)
            }
        }
        .sheet(isPresented: $showAccountSwitcher) {
            AccountSwitcherSheet()
                .environment(appState)
        }
    }
}
