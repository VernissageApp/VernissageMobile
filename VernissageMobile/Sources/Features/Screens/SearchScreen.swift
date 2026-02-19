//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct SearchScreen: View {
    @EnvironmentObject private var appState: AppState

    @State private var query = ""
    @State private var selectedScope: SearchScopeSelection = .statuses
    @State private var isSearching = false
    @State private var searchExecuted = false
    @State private var errorMessage: String?
    @State private var users: [User] = []
    @State private var hashtags: [Hashtag] = []
    @State private var statuses: [Status] = []
    @State private var isShowingProfile = false
    @State private var showAddSheet = false

    @Binding private var showAccountSwitcher: Bool

    init(showAccountSwitcher: Binding<Bool>) {
        _showAccountSwitcher = showAccountSwitcher
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    Picker("Search scope", selection: $selectedScope) {
                        ForEach(SearchScopeSelection.allCases, id: \.self) { scope in
                            Text(scope.title).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedScope, initial: false) { _, _ in
                        guard searchExecuted, !isSearching, query.nilIfEmpty != nil else {
                            return
                        }

                        Task { await executeSearch(autoSelectScope: false) }
                    }

                    if isSearching {
                        ProgressView()
                            .tint(.white)
                            .padding(.top, 8)
                    } else if errorMessage != nil {
                        EmptyView()
                    } else if searchExecuted {
                        searchResultsView
                    } else {
                        ContentUnavailableView("Start searching",
                                               systemImage: "magnifyingglass",
                                               description: Text("Search for a user, status, hashtag, or paste a profile/status URL."))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .navigationTitle("Search")
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
            .searchable(text: $query, prompt: "Enter query...")
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .onSubmit(of: .search) {
                Task { await executeSearch(autoSelectScope: true) }
            }
            .onChange(of: query) { _, newValue in
                if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    searchExecuted = false
                    errorMessage = nil
                    users = []
                    hashtags = []
                    statuses = []
                }
            }
        }
        .errorAlertToast($errorMessage)
        .sheet(isPresented: $showAddSheet) {
            AddStatusPlaceholderSheet()
        }
    }

    @ViewBuilder
    private var searchResultsView: some View {
        switch selectedScope {
        case .users:
            if users.isEmpty {
                ContentUnavailableView("No users found",
                                       systemImage: "person.3",
                                       description: Text("Try a different query."))
                    .foregroundStyle(.secondary)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(users.enumerated()), id: \.offset) { index, user in
                        ProfileUserRowView(user: user)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 10)

                        if index < users.count - 1 {
                            Divider()
                                .padding(.leading, 84)
                                .padding(.trailing, 8)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .liquidGlassCard()
            }
        case .hashtags:
            if hashtags.isEmpty {
                ContentUnavailableView("No hashtags found",
                                       systemImage: "number",
                                       description: Text("Try a different query."))
                    .foregroundStyle(.secondary)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(hashtags.enumerated()), id: \.offset) { index, hashtag in
                        HashtagSearchRowView(hashtag: hashtag)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)

                        if index < hashtags.count - 1 {
                            Divider()
                                .padding(.leading, 14)
                                .padding(.trailing, 14)
                        }
                    }
                }
                .liquidGlassCard()
            }
        case .statuses:
            if statuses.isEmpty {
                ContentUnavailableView("No statuses found",
                                       systemImage: "photo.on.rectangle.angled",
                                       description: Text("Try a different query."))
                    .foregroundStyle(.secondary)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(statuses, id: \.id) { status in
                        NavigationLink {
                            StatusDetailScreen(status: status)
                        } label: {
                            SearchStatusRowView(status: status)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @MainActor
    private func executeSearch(autoSelectScope: Bool) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            searchExecuted = false
            errorMessage = nil
            users = []
            hashtags = []
            statuses = []
            return
        }

        if autoSelectScope {
            searchExecuted = false
            selectedScope = SearchScopeSelection.fromQuery(trimmedQuery)
        }

        isSearching = true
        defer { isSearching = false }

        do {
            let result = try await appState.search(query: trimmedQuery, type: selectedScope.rawValue)
            users = result.users ?? []
            hashtags = result.hashtags ?? []
            statuses = result.statuses ?? []
            errorMessage = nil
            searchExecuted = true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            users = []
            hashtags = []
            statuses = []
            searchExecuted = true
        }
    }
}
