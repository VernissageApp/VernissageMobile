//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct EditorsScreen: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var photosViewModel = TimelineViewModel(kind: .editorsChoice)
    @StateObject private var artistsViewModel = FeaturedUsersViewModel()
    @State private var selectedContent: EditorsContentSelection = .photos
    @State private var hasCompletedInitialPhotosLoad = false
    @State private var isShowingProfile = false
    @State private var showAddSheet = false
    @Binding private var showAccountSwitcher: Bool

    init(showAccountSwitcher: Binding<Bool>) {
        _showAccountSwitcher = showAccountSwitcher
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    Picker("Editor's content type", selection: $selectedContent) {
                        ForEach(EditorsContentSelection.allCases, id: \.self) { item in
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

                    if selectedContent == .photos {
                        photosSection
                    } else {
                        artistsSection
                    }
                }
            }
            .navigationTitle("Editor's choice")
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
            .onFirstAppear {
                artistsViewModel.reset()
                await loadSelectedContentIfNeeded(force: true)
            }
            .onChange(of: selectedContent, initial: false) { _, _ in
                Task {
                    await loadSelectedContentIfNeeded(force: false)
                }
            }
            .refreshable {
                HapticFeedbackHelper.timelineRefreshStarted()
                await loadSelectedContentIfNeeded(force: true)
            }
            .errorAlertToast(Binding(
                get: { photosViewModel.errorMessage },
                set: { photosViewModel.errorMessage = $0 }
            ))
            .errorAlertToast(Binding(
                get: { artistsViewModel.errorMessage },
                set: { artistsViewModel.errorMessage = $0 }
            ))
        }
        .id(appState.activeAccountID)
        .sheet(isPresented: $showAddSheet) {
            AddStatusPlaceholderSheet()
        }
    }

    @ViewBuilder
    private var photosSection: some View {
        if photosViewModel.statuses.isEmpty && (!hasCompletedInitialPhotosLoad || photosViewModel.isLoading) {
            ProgressView()
                .tint(.primary)
        } else if photosViewModel.errorMessage != nil, photosViewModel.statuses.isEmpty {
            ContentUnavailableView("Cannot load editor's photos",
                                   systemImage: "exclamationmark.triangle",
                                   description: Text("Please try again in a moment."))
                .foregroundStyle(.secondary)
        } else if photosViewModel.photoStatuses.isEmpty {
            ContentUnavailableView("No featured photos",
                                   systemImage: "photo.on.rectangle.angled",
                                   description: Text("There are no featured photos yet."))
                .foregroundStyle(.secondary)
        } else {
            LazyVStack(spacing: 8) {
                ForEach(photosViewModel.photoStatuses, id: \.id) { status in
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
                    .onAppear {
                        Task {
                            await photosViewModel.loadMoreIfNeeded(using: appState, currentStatusID: status.id)
                        }
                    }
                }

                if photosViewModel.isLoadingMore {
                    ProgressView()
                        .tint(.primary)
                        .padding(.vertical, 12)
                }
            }
        }
    }

    @ViewBuilder
    private var artistsSection: some View {
        if artistsViewModel.isLoading && artistsViewModel.users.isEmpty {
            ProgressView()
                .tint(.primary)
        } else if artistsViewModel.errorMessage != nil, artistsViewModel.users.isEmpty {
            ContentUnavailableView("Cannot load featured artists",
                                   systemImage: "exclamationmark.triangle",
                                   description: Text("Please try again in a moment."))
                .foregroundStyle(.secondary)
        } else if artistsViewModel.users.isEmpty {
            ContentUnavailableView("No featured artists",
                                   systemImage: "person.3",
                                   description: Text("There are no featured artists yet."))
                .foregroundStyle(.secondary)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(Array(artistsViewModel.users.enumerated()), id: \.element.uniquenessKey) { index, user in
                    TrendingArtistRowView(
                        user: user,
                        statuses: artistsViewModel.userStatusesByKey[user.uniquenessKey],
                        isLoadingStatuses: artistsViewModel.loadingStatusesUserKeys.contains(user.uniquenessKey)
                    )
                    .id(user.uniquenessKey)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .onFirstAppear(id: "\(user.uniquenessKey)-\(artistsViewModel.artistsRefreshToken)") {
                        await artistsViewModel.loadStatusesIfNeeded(using: appState, user: user)
                        await artistsViewModel.loadMoreIfNeeded(using: appState, currentUser: user)
                    }

                    if index < artistsViewModel.users.count - 1 {
                        Divider()
                            .padding(.horizontal, 16)
                    }
                }

                if artistsViewModel.isLoadingMore {
                    ProgressView()
                        .tint(.primary)
                        .padding(.vertical, 12)
                }
            }
        }
    }

    @MainActor
    private func loadSelectedContentIfNeeded(force: Bool) async {
        switch selectedContent {
        case .photos:
            await photosViewModel.load(using: appState, forceRefresh: force)
            hasCompletedInitialPhotosLoad = true
        case .artists:
            await artistsViewModel.load(using: appState, forceRefresh: force)
        }
    }
}
