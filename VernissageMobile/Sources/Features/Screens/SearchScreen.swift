//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct SearchScreen: View {
    @Environment(AppState.self) private var appState

    @State private var query = ""
    @State private var selectedScope: SearchScopeSelection = .statuses
    @State private var isSearching = false
    @State private var searchExecuted = false
    @State private var errorMessage: String?
    @State private var users: [User] = []
    @State private var hashtags: [Hashtag] = []
    @State private var statuses: [Status] = []
    @State private var userStatusesByKey: [String: [Status]] = [:]
    @State private var loadingUserKeys: Set<String> = []
    @State private var userStatusesRefreshToken = UUID()
    @State private var hashtagStatusesByName: [String: [Status]] = [:]
    @State private var loadingHashtagNames: Set<String> = []
    @State private var hashtagStatusesRefreshToken = UUID()
    @State private var isShowingProfile = false
    @State private var hashtagTimelineRoute: HashtagTimelineRoute?
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
            .navigationDestination(item: $hashtagTimelineRoute) { route in
                HashtagTimelineScreen(hashtagName: route.hashtagName)
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
                    userStatusesByKey = [:]
                    loadingUserKeys = []
                    userStatusesRefreshToken = UUID()
                    hashtagStatusesByName = [:]
                    loadingHashtagNames = []
                    hashtagStatusesRefreshToken = UUID()
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
                    ForEach(users.indices, id: \.self) { index in
                        let user = users[index]
                        TrendingArtistRowView(
                            user: user,
                            statuses: userStatusesByKey[user.uniquenessKey],
                            isLoadingStatuses: loadingUserKeys.contains(user.uniquenessKey)
                        )
                            .id(user.uniquenessKey)
                            .padding(.vertical, 10)
                            .onFirstAppear(id: "\(user.uniquenessKey)-\(userStatusesRefreshToken.uuidString)") {
                                await loadUserStatusesIfNeeded(
                                    user: user,
                                    searchToken: userStatusesRefreshToken
                                )
                            }

                        if index < users.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        case .hashtags:
            if hashtags.isEmpty {
                ContentUnavailableView("No hashtags found",
                                       systemImage: "number",
                                       description: Text("Try a different query."))
                    .foregroundStyle(.secondary)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(hashtags.indices, id: \.self) { index in
                        let hashtag = hashtags[index]
                        let hashtagNameKey = hashtag.name.lowercased()
                        TrendingTagRowView(
                            hashtag: hashtag,
                            statuses: hashtagStatusesByName[hashtagNameKey],
                            isLoadingStatuses: loadingHashtagNames.contains(hashtagNameKey)
                        ) {
                            hashtagTimelineRoute = HashtagTimelineRoute(hashtagName: hashtag.name)
                        }
                            .padding(.vertical, 10)
                            .onFirstAppear(id: "\(hashtagNameKey)-\(hashtagStatusesRefreshToken.uuidString)") {
                                await loadHashtagStatusesIfNeeded(
                                    hashtag: hashtag,
                                    searchToken: hashtagStatusesRefreshToken
                                )
                            }

                        if index < hashtags.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        case .statuses:
            if statuses.isEmpty {
                ContentUnavailableView("No statuses found",
                                       systemImage: "photo.on.rectangle.angled",
                                       description: Text("Try a different query."))
                    .foregroundStyle(.secondary)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(statuses, id: \.id) { status in
                        NavigationLink {
                            StatusDetailScreen(status: status)
                        } label: {
                            SearchStatusRowView(status: status)
                        }
                        .buttonStyle(.plain)
                        .padding(12)
                        .liquidGlassCard()
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
            userStatusesByKey = [:]
            loadingUserKeys = []
            userStatusesRefreshToken = UUID()
            hashtagStatusesByName = [:]
            loadingHashtagNames = []
            hashtagStatusesRefreshToken = UUID()
            return
        }

        if autoSelectScope {
            searchExecuted = false
            selectedScope = SearchScopeSelection.fromQuery(trimmedQuery)
        }

        userStatusesByKey = [:]
        loadingUserKeys = []
        userStatusesRefreshToken = UUID()
        hashtagStatusesByName = [:]
        loadingHashtagNames = []
        hashtagStatusesRefreshToken = UUID()

        isSearching = true
        defer { isSearching = false }

        do {
            let result = try await appState.api.search.search(query: trimmedQuery, type: selectedScope.rawValue)
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
            userStatusesByKey = [:]
            loadingUserKeys = []
            userStatusesRefreshToken = UUID()
            hashtagStatusesByName = [:]
            loadingHashtagNames = []
            hashtagStatusesRefreshToken = UUID()
            searchExecuted = true
        }
    }

    @MainActor
    private func loadUserStatusesIfNeeded(user: User, searchToken: UUID) async {
        guard searchToken == userStatusesRefreshToken else {
            return
        }

        let key = user.uniquenessKey
        guard !loadingUserKeys.contains(key), userStatusesByKey[key] == nil else {
            return
        }

        guard let userName = user.userName?.trimmingPrefix("@").nilIfEmpty else {
            userStatusesByKey[key] = []
            return
        }

        loadingUserKeys.insert(key)
        defer { loadingUserKeys.remove(key) }

        do {
            let page = try await appState.api.timelines.fetchUserStatuses(userName: userName, maxId: nil, limit: 10)
            guard searchToken == userStatusesRefreshToken else {
                return
            }

            userStatusesByKey[key] = page.data.filter(\.hasAttachment)
        } catch {
            guard searchToken == userStatusesRefreshToken else {
                return
            }

            if error.isCancellationLike {
                return
            }

            userStatusesByKey[key] = []
        }
    }

    @MainActor
    private func loadHashtagStatusesIfNeeded(hashtag: Hashtag, searchToken: UUID) async {
        guard searchToken == hashtagStatusesRefreshToken else {
            return
        }

        let key = hashtag.name.lowercased()
        guard !loadingHashtagNames.contains(key), hashtagStatusesByName[key] == nil else {
            return
        }

        loadingHashtagNames.insert(key)
        defer { loadingHashtagNames.remove(key) }

        do {
            let page = try await appState.api.timelines.fetchHashtagStatuses(hashtag: hashtag.name, maxId: nil, limit: 10)
            guard searchToken == hashtagStatusesRefreshToken else {
                return
            }

            hashtagStatusesByName[key] = page.data.filter(\.hasAttachment)
        } catch {
            guard searchToken == hashtagStatusesRefreshToken else {
                return
            }

            if error.isCancellationLike {
                return
            }

            hashtagStatusesByName[key] = []
        }
    }
}
