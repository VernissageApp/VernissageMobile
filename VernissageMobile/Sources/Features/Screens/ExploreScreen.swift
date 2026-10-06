//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ExploreScreen: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = ExploreViewModel()
    @State private var selectedContent: ExploreContentSelection = .categories
    @State private var categoriesQuery = ""
    @State private var camerasQuery = ""
    @State private var lensesQuery = ""
    @State private var filmsQuery = ""
    @State private var isShowingProfile = false
    @State private var refreshFeedbackTrigger = false
    @State private var showAddSheet = false

    @Binding private var showAccountSwitcher: Bool

    init(showAccountSwitcher: Binding<Bool>) {
        _showAccountSwitcher = showAccountSwitcher
    }

    var body: some View {
        @Bindable var bindableViewModel = viewModel

        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    Picker("Explore type", selection: $selectedContent) {
                        ForEach(ExploreContentSelection.allCases, id: \.self) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 2)

                    Text(selectedContent.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)

                    switch selectedContent {
                    case .categories:
                        ExploreContentListView(
                            selection: .categories,
                            query: $categoriesQuery,
                            viewModel: viewModel
                        )
                    case .cameras:
                        ExploreContentListView(
                            selection: .cameras,
                            query: $camerasQuery,
                            viewModel: viewModel
                        )
                    case .lenses:
                        ExploreContentListView(
                            selection: .lenses,
                            query: $lensesQuery,
                            viewModel: viewModel
                        )
                    case .films:
                        ExploreContentListView(
                            selection: .films,
                            query: $filmsQuery,
                            viewModel: viewModel
                        )
                    }
                }
            }
            .navigationTitle("Explore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    AccountSwitcherToolbarAvatarButtonView(avatarURL: appState.activeAccount?.avatarURL) {
                        isShowingProfile = true
                    } onLongPress: {
                        showAccountSwitcher = true
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        AddToolbarButtonView {
                            showAddSheet = true
                        }
                        SettingsToolbarButtonView()
                        NotificationsToolbarButtonView()
                    }
                }
            }
            .navigationDestination(isPresented: $isShowingProfile) {
                ProfileScreen(showAccountSwitcher: $showAccountSwitcher)
            }
            .navigationDestination(for: ExploreTimelineRoute.self) { route in
                ExploreTimelineScreen(item: route.item, selection: route.selection)
            }
            .onFirstAppear {
                await loadSelectedContent()
            }
            .onChange(of: selectedContent, initial: false) { _, _ in
                Task {
                    await loadSelectedContent()
                }
            }
            .onChange(of: appState.activeAccountID, initial: false) { _, _ in
                viewModel.reset()
                Task {
                    await loadSelectedContent()
                }
            }
            .refreshable {
                await viewModel.refresh(
                    selection: selectedContent,
                    query: selectedQuery,
                    using: appState
                )

                guard !Task.isCancelled else {
                    return
                }

                refreshFeedbackTrigger.toggle()
            }
            .errorAlertToast($bindableViewModel.errorMessage)
            .sensoryFeedback(.impact, trigger: refreshFeedbackTrigger)
        }
        .id(appState.activeAccountID)
        .sheet(isPresented: $showAddSheet) {
            AddStatusPlaceholderSheet()
        }
    }

    private var selectedQuery: String {
        switch selectedContent {
        case .categories:
            categoriesQuery
        case .cameras:
            camerasQuery
        case .lenses:
            lensesQuery
        case .films:
            filmsQuery
        }
    }

    private func loadSelectedContent() async {
        await viewModel.loadIfNeeded(
            selection: selectedContent,
            query: selectedQuery,
            using: appState
        )
    }
}
