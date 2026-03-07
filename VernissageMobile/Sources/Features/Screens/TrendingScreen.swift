//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct TrendingScreen: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = TrendingViewModel()
    @State private var selectedContent: TrendingContentSelection = .photos
    @State private var isShowingProfile = false
    @State private var refreshFeedbackTrigger = false
    @State private var showAddSheet = false
    @State private var hashtagTimelineRoute: HashtagTimelineRoute?

    @Binding private var showAccountSwitcher: Bool

    init(showAccountSwitcher: Binding<Bool>) {
        _showAccountSwitcher = showAccountSwitcher
    }

    var body: some View {
        @Bindable var bindableViewModel = viewModel

        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    Picker("Trending type", selection: $selectedContent) {
                        ForEach(TrendingContentSelection.allCases, id: \.self) { item in
                            Label(item.title, systemImage: item.systemImage)
                                .tag(item)
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

                    contentSection
                }
            }
            .navigationTitle("Trending")
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
            .onFirstAppear {
                await loadSelectedContent(force: false)
            }
            .onChange(of: appState.activeAccountID, initial: false) { _, _ in
                Task {
                    await loadSelectedContent(force: true)
                }
            }
            .onChange(of: selectedContent, initial: false) { _, _ in
                Task {
                    await loadSelectedContent(force: false)
                }
            }
            .refreshable {
                await loadSelectedContent(force: true)

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

    @ViewBuilder
    private var contentSection: some View {
        switch selectedContent {
        case .photos:
            photosSection
        case .artists:
            artistsSection
        case .tags:
            tagsSection
        }
    }

    @ViewBuilder
    private var photosSection: some View {
        if viewModel.isPhotosLoading && viewModel.photoStatuses.isEmpty {
            ProgressView()
                .tint(.primary)
        } else if viewModel.photosErrorMessage != nil, viewModel.photoStatuses.isEmpty {
            ContentUnavailableView("Cannot load trending photos",
                                   systemImage: "exclamationmark.triangle",
                                   description: Text("Please try again in a moment."))
                .foregroundStyle(.secondary)
        } else if viewModel.photoStatuses.isEmpty {
            ContentUnavailableView("No trending photos",
                                   systemImage: "photo.on.rectangle.angled",
                                   description: Text("There are no trending photos for the selected period."))
                .foregroundStyle(.secondary)
        } else {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.photoStatuses, id: \.id) { status in
                    NavigationLink {
                        StatusDetailScreen(status: status)
                    } label: {
                        TimelinePhotoTileView(
                            status: status,
                            showsAuthorOverlay: true,
                            showsContentWarningOverlay: true,
                            showsImageCountOverlay: true
                        )
                    }
                    .buttonStyle(.plain)
                    .onFirstAppear {
                        await viewModel.loadMorePhotosIfNeeded(
                            using: appState,
                            period: .daily,
                            currentStatusID: status.id
                        )
                    }
                }

                if viewModel.isPhotosLoadingMore {
                    ProgressView()
                        .tint(.primary)
                        .padding(.vertical, 12)
                }
            }
        }
    }

    @ViewBuilder
    private var artistsSection: some View {
        if viewModel.isArtistsLoading && viewModel.artists.isEmpty {
            ProgressView()
                .tint(.primary)
        } else if viewModel.artistsErrorMessage != nil, viewModel.artists.isEmpty {
            ContentUnavailableView("Cannot load trending artists",
                                   systemImage: "exclamationmark.triangle",
                                   description: Text("Please try again in a moment."))
                .foregroundStyle(.secondary)
        } else if viewModel.artists.isEmpty {
            ContentUnavailableView("No trending artists",
                                   systemImage: "person.3",
                                   description: Text("There are no trending artists for the selected period."))
                .foregroundStyle(.secondary)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.artists.indices, id: \.self) { index in
                    let user = viewModel.artists[index]
                    TrendingArtistRowView(
                        user: user,
                        statuses: viewModel.artistStatusesByKey[user.uniquenessKey],
                        isLoadingStatuses: viewModel.loadingArtistKeys.contains(user.uniquenessKey)
                    )
                    .id(user.uniquenessKey)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .onFirstAppear(id: "\(user.uniquenessKey)-\(viewModel.artistsRefreshToken)") {
                        await viewModel.loadArtistStatusesIfNeeded(using: appState, user: user)
                        await viewModel.loadMoreArtistsIfNeeded(
                            using: appState,
                            period: .daily,
                            currentUser: user
                        )
                    }

                    if index < viewModel.artists.count - 1 {
                        Divider()
                            .padding(.horizontal, 16)
                    }
                }

                if viewModel.isArtistsLoadingMore {
                    ProgressView()
                        .tint(.primary)
                        .padding(.vertical, 12)
                }
            }
        }
    }

    @ViewBuilder
    private var tagsSection: some View {
        if viewModel.isTagsLoading && viewModel.hashtags.isEmpty {
            ProgressView()
                .tint(.primary)
        } else if viewModel.tagsErrorMessage != nil, viewModel.hashtags.isEmpty {
            ContentUnavailableView("Cannot load trending tags",
                                   systemImage: "exclamationmark.triangle",
                                   description: Text("Please try again in a moment."))
                .foregroundStyle(.secondary)
        } else if viewModel.hashtags.isEmpty {
            ContentUnavailableView("No trending tags",
                                   systemImage: "number",
                                   description: Text("There are no trending tags for the selected period."))
                .foregroundStyle(.secondary)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.hashtags.indices, id: \.self) { index in
                    let hashtag = viewModel.hashtags[index]
                    TrendingTagRowView(
                        hashtag: hashtag,
                        statuses: viewModel.tagStatusesByName[hashtag.name.lowercased()],
                        isLoadingStatuses: viewModel.loadingTagNames.contains(hashtag.name.lowercased())
                    )
                    {
                        hashtagTimelineRoute = HashtagTimelineRoute(hashtagName: hashtag.name)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .onFirstAppear(id: "\(hashtag.name.lowercased())-\(viewModel.tagsRefreshToken)") {
                        await viewModel.loadTagStatusesIfNeeded(using: appState, hashtag: hashtag)
                        await viewModel.loadMoreTagsIfNeeded(
                            using: appState,
                            period: .daily,
                            currentHashtag: hashtag
                        )
                    }

                    if index < viewModel.hashtags.count - 1 {
                        Divider()
                            .padding(.horizontal, 16)
                    }
                }

                if viewModel.isTagsLoadingMore {
                    ProgressView()
                        .tint(.primary)
                        .padding(.vertical, 12)
                }
            }
        }
    }

    @MainActor
    private func loadSelectedContent(force: Bool) async {
        switch selectedContent {
        case .photos:
            await viewModel.loadPhotos(using: appState, period: .daily, forceRefresh: force)
        case .artists:
            await viewModel.loadArtists(using: appState, period: .daily, forceRefresh: force)
        case .tags:
            await viewModel.loadTags(using: appState, period: .daily, forceRefresh: force)
        }
    }
}
