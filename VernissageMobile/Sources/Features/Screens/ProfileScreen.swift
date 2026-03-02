//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ProfileScreen: View {
    @EnvironmentObject private var appState: AppState
    @State private var profile: User?
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var selectedContentTab: ProfileContentTab = .photos

    @State private var statuses: [Status] = []
    @State private var statusesErrorMessage: String?
    @State private var isStatusesLoading = false
    @State private var isLoadingMoreStatuses = false
    @State private var nextStatusesMaxId: String?
    @State private var canLoadMoreStatuses = true

    @State private var followingUsers: [User] = []
    @State private var followingErrorMessage: String?
    @State private var isFollowingLoading = false
    @State private var isLoadingMoreFollowing = false
    @State private var nextFollowingMaxId: String?
    @State private var canLoadMoreFollowing = true

    @State private var followersUsers: [User] = []
    @State private var followersErrorMessage: String?
    @State private var isFollowersLoading = false
    @State private var isLoadingMoreFollowers = false
    @State private var nextFollowersMaxId: String?
    @State private var canLoadMoreFollowers = true
    @State private var relationshipsByUserID: [String: Relationship] = [:]

    @State private var latestFollowers: [User] = []
    @State private var profileCollectionDestination: ProfileDestination?
    @State private var isShowingProfileCode = false
    @State private var isShowingProfileEdit = false
    @State private var isShowingAvatarChooser = false
    @State private var isShowingHeaderChooser = false
    @State private var isShowingDeleteAccount = false

    @Binding private var showAccountSwitcher: Bool

    init(showAccountSwitcher: Binding<Bool>) {
        _showAccountSwitcher = showAccountSwitcher
    }

    private var photoStatuses: [Status] {
        statuses.filter(\.hasAttachment)
    }

    private var isAdministratorBadgeVisible: Bool {
        if appState.activeTokenRoles.contains("administrator") {
            return true
        }

        return profile?.roles?.contains(where: { $0.compare("administrator", options: .caseInsensitive) == .orderedSame }) == true
    }

    private var profileShareURL: String? {
        if let directURL = profile?.url?.nilIfEmpty {
            return directURL
        }

        let accountBaseURL = appState.activeAccount?.instanceURL
        let userName = profile?.userName
        return fallbackProfileURL(baseURLString: accountBaseURL, userName: userName)
    }

    private var shouldShowProfileSkeleton: Bool {
        profile == nil && errorMessage == nil
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            ScrollView {
                if shouldShowProfileSkeleton {
                    ProfileLoadingSkeletonView(showCollectionsActions: false)
                } else {
                    LazyVStack(spacing: 16) {
                        VStack(spacing: 16) {
                            if isLoading && profile == nil {
                                ProgressView().tint(.primary)
                            }

                            if let profile {
                                ProfileOverviewCardView(profile: profile,
                                                    latestFollowers: latestFollowers,
                                                    isAdministrator: isAdministratorBadgeVisible)
                            }
                        }

                        ProfileContentTabsView(selectedTab: $selectedContentTab)
                            .padding(.horizontal, 16)

                        if selectedContentTab == .photos {
                            photosSection
                        } else if selectedContentTab == .following {
                            followingSection
                        } else {
                            followersSection
                        }
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .id(appState.activeAccountID)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                SettingsToolbarButtonView()
            }
            ToolbarItem(placement: .topBarTrailing) {
                profileActionsToolbarMenu
            }
        }
        .navigationDestination(item: $profileCollectionDestination) { destination in
            switch destination {
            case .favourites:
                ProfilePhotoCollectionScreen(kind: .favourites)
            case .bookmarks:
                ProfilePhotoCollectionScreen(kind: .bookmarks)
            case .instance:
                InstanceInformationScreen()
            case .sharedBusinessCards:
                SharedBusinessCardsScreen()
            }
        }
        .sheet(isPresented: $isShowingProfileCode) {
            if let profileShareURL = profileShareURL?.nilIfEmpty {
                ProfileQRCodeSheet(profileURL: profileShareURL)
            }
        }
        .sheet(isPresented: $isShowingProfileEdit) {
            if let profile {
                ProfileEditSheet(profile: profile) { updatedProfile in
                    self.profile = updatedProfile
                }
                .environmentObject(appState)
            }
        }
        .sheet(isPresented: $isShowingAvatarChooser) {
            if let profile {
                ProfileAvatarSheet(profile: profile) { updatedProfile in
                    self.profile = updatedProfile
                }
                .environmentObject(appState)
            }
        }
        .sheet(isPresented: $isShowingHeaderChooser) {
            if let profile {
                ProfileHeaderSheet(profile: profile) { updatedProfile in
                    self.profile = updatedProfile
                }
                .environmentObject(appState)
            }
        }
        .sheet(isPresented: $isShowingDeleteAccount) {
            DeleteAccountSheet(requiredEmail: profile?.email) {
                if let activeAccountID = appState.activeAccountID {
                    appState.removeAccount(id: activeAccountID)
                }
            }
            .environmentObject(appState)
        }
        .onChange(of: selectedContentTab, initial: false) { oldTab, newTab in
            Task {
                await loadSelectedTabIfNeeded(newTab)
            }
        }
        .onFirstAppear {
            await loadProfile()
        }
        .errorAlertToast($errorMessage)
        .errorAlertToast($statusesErrorMessage)
        .errorAlertToast($followingErrorMessage)
        .errorAlertToast($followersErrorMessage)
    }

    private var profileActionsToolbarMenu: some View {
        Menu {
            if let profileShareURLObject {
                ShareLink(item: profileShareURLObject) {
                    Label("Share profile", systemImage: "square.and.arrow.up")
                }
            }
            
            Button {
                isShowingProfileCode = true
            } label: {
                Label("QR code", systemImage: "qrcode")
            }
            .disabled(profileShareURL?.nilIfEmpty == nil)

            Button {
                profileCollectionDestination = .sharedBusinessCards
            } label: {
                Label("Shared cards", systemImage: "person.crop.square")
            }

            Divider()
            
            Button {
                profileCollectionDestination = .favourites
            } label: {
                Label("Favourites", systemImage: "star.fill")
            }

            Button {
                profileCollectionDestination = .bookmarks
            } label: {
                Label("Bookmarks", systemImage: "bookmark.fill")
            }

            Button {
                profileCollectionDestination = .instance
            } label: {
                Label("Instance", systemImage: "building.2.fill")
            }

            Divider()
            
            Button {
                isShowingProfileEdit = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                isShowingAvatarChooser = true
            } label: {
                Label("Change avatar", systemImage: "person.crop.circle.badge.plus")
            }

            Button {
                isShowingHeaderChooser = true
            } label: {
                Label("Change header", systemImage: "photo.badge.plus")
            }
            
            Divider()

            Button(role: .destructive) {
                isShowingDeleteAccount = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .disabled(profile?.email?.nilIfEmpty == nil)
        } label: {
            Image(systemName: "ellipsis")
                .font(.title3)
        }
    }

    @ViewBuilder
    private var photosSection: some View {
        if isStatusesLoading && photoStatuses.isEmpty {
            ProgressView()
                .tint(.primary)
                .padding(.top, 4)
        } else if statusesErrorMessage != nil, photoStatuses.isEmpty {
            EmptyView()
        } else if !isStatusesLoading && photoStatuses.isEmpty {
            ContentUnavailableView("No photos",
                                   systemImage: "photo.on.rectangle.angled",
                                   description: Text("This user has no statuses with photos yet."))
                .padding(.horizontal, 16)
        } else {
            LazyVStack(spacing: 8) {
                ForEach(photoStatuses, id: \.id) { status in
                    NavigationLink {
                        StatusDetailScreen(status: status)
                    } label: {
                        TimelinePhotoTileView(status: status, showsImageCountOverlay: true)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        Task {
                            await loadMoreStatusesIfNeeded(currentStatusID: status.id)
                        }
                    }
                }

                if isLoadingMoreStatuses {
                    ProgressView()
                        .tint(.primary)
                        .padding(.vertical, 12)
                }
            }
        }
    }

    private var followingSection: some View {
        ProfileUsersListView(users: followingUsers,
                             isLoading: isFollowingLoading,
                             isLoadingMore: isLoadingMoreFollowing,
                             errorMessage: followingErrorMessage,
                             emptyTitle: "No following",
                             emptyDescription: "This user is not following anyone yet.",
                             showFollowButtons: true,
                             singleButton: true,
                             relationshipsByUserID: relationshipsByUserID,
                             onRelationshipChanged: { userId, relationship in
                                relationshipsByUserID[userId] = relationship
                             }) { currentIndex in
            Task {
                await loadMoreFollowingIfNeeded(currentIndex: currentIndex)
            }
        }
    }

    private var followersSection: some View {
        ProfileUsersListView(users: followersUsers,
                             isLoading: isFollowersLoading,
                             isLoadingMore: isLoadingMoreFollowers,
                             errorMessage: followersErrorMessage,
                             emptyTitle: "No followers",
                             emptyDescription: "This user has no followers yet.",
                             showFollowButtons: true,
                             singleButton: true,
                             relationshipsByUserID: relationshipsByUserID,
                             onRelationshipChanged: { userId, relationship in
                                relationshipsByUserID[userId] = relationship
                             }) { currentIndex in
            Task {
                await loadMoreFollowersIfNeeded(currentIndex: currentIndex)
            }
        }
    }

    @MainActor
    private func loadProfile() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let downloadedProfile = try await appState.fetchActiveProfile()
            profile = downloadedProfile
            errorMessage = nil
            await loadStatuses(for: downloadedProfile.userName)
            await loadLatestFollowers(for: downloadedProfile.userName)

            if selectedContentTab == .following {
                await loadFollowing(for: downloadedProfile.userName, reset: true)
            } else if selectedContentTab == .followers {
                await loadFollowers(for: downloadedProfile.userName, reset: true)
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            statuses = []
            statusesErrorMessage = nil
            isStatusesLoading = false
            isLoadingMoreStatuses = false
            nextStatusesMaxId = nil
            canLoadMoreStatuses = false
            followingUsers = []
            followersUsers = []
            latestFollowers = []
            relationshipsByUserID = [:]
        }
    }

    @MainActor
    private func loadSelectedTabIfNeeded(_ tab: ProfileContentTab) async {
        switch tab {
        case .photos:
            return
        case .following:
            guard !isFollowingLoading, followingUsers.isEmpty else {
                return
            }
            await loadFollowing(for: profile?.userName, reset: true)
        case .followers:
            guard !isFollowersLoading, followersUsers.isEmpty else {
                return
            }
            await loadFollowers(for: profile?.userName, reset: true)
        }
    }

    @MainActor
    private func loadStatuses(for userName: String?) async {
        statuses = []
        nextStatusesMaxId = nil
        canLoadMoreStatuses = true

        guard let userName = userName?.trimmingPrefix("@").nilIfEmpty else {
            statusesErrorMessage = nil
            canLoadMoreStatuses = false
            return
        }

        isStatusesLoading = true
        defer { isStatusesLoading = false }

        do {
            let page = try await appState.fetchUserStatuses(userName: userName, maxId: nil)
            statuses = page.data
            nextStatusesMaxId = page.maxId
            canLoadMoreStatuses = page.maxId != nil && !page.data.isEmpty
            statusesErrorMessage = nil
        } catch {
            statusesErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            statuses = []
            nextStatusesMaxId = nil
            canLoadMoreStatuses = false
        }
    }

    @MainActor
    private func loadMoreStatusesIfNeeded(currentStatusID: String) async {
        guard !isLoading, !isStatusesLoading, !isLoadingMoreStatuses, canLoadMoreStatuses else {
            return
        }

        guard currentStatusID == photoStatuses.last?.id else {
            return
        }

        guard let cursor = nextStatusesMaxId?.nilIfEmpty else {
            canLoadMoreStatuses = false
            return
        }

        guard let userName = profile?.userName?.trimmingPrefix("@").nilIfEmpty else {
            canLoadMoreStatuses = false
            return
        }

        isLoadingMoreStatuses = true
        defer { isLoadingMoreStatuses = false }

        do {
            let page = try await appState.fetchUserStatuses(userName: userName, maxId: cursor)
            appendUniqueStatuses(page.data)
            nextStatusesMaxId = page.maxId
            canLoadMoreStatuses = page.maxId != nil && !page.data.isEmpty
            statusesErrorMessage = nil
        } catch {
            statusesErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    @MainActor
    private func loadFollowing(for userName: String?, reset: Bool) async {
        if reset {
            followingUsers = []
            nextFollowingMaxId = nil
            canLoadMoreFollowing = true
        }

        guard let cleanedName = userName?.trimmingPrefix("@").nilIfEmpty else {
            followingErrorMessage = nil
            canLoadMoreFollowing = false
            return
        }

        isFollowingLoading = true
        defer { isFollowingLoading = false }

        do {
            let page = try await appState.fetchUserFollowing(userName: cleanedName, maxId: nil)
            followingUsers = page.data
            await refreshRelationships(for: page.data)
            nextFollowingMaxId = page.maxId
            canLoadMoreFollowing = page.maxId != nil && !page.data.isEmpty
            followingErrorMessage = nil
        } catch {
            followingErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            followingUsers = []
            nextFollowingMaxId = nil
            canLoadMoreFollowing = false
        }
    }

    @MainActor
    private func loadFollowers(for userName: String?, reset: Bool) async {
        if reset {
            followersUsers = []
            nextFollowersMaxId = nil
            canLoadMoreFollowers = true
        }

        guard let cleanedName = userName?.trimmingPrefix("@").nilIfEmpty else {
            followersErrorMessage = nil
            canLoadMoreFollowers = false
            return
        }

        isFollowersLoading = true
        defer { isFollowersLoading = false }

        do {
            let page = try await appState.fetchUserFollowers(userName: cleanedName, maxId: nil)
            followersUsers = page.data
            await refreshRelationships(for: page.data)
            nextFollowersMaxId = page.maxId
            canLoadMoreFollowers = page.maxId != nil && !page.data.isEmpty
            followersErrorMessage = nil
        } catch {
            followersErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            followersUsers = []
            nextFollowersMaxId = nil
            canLoadMoreFollowers = false
        }
    }

    @MainActor
    private func loadMoreFollowingIfNeeded(currentIndex: Int) async {
        guard selectedContentTab == .following,
              currentIndex == followingUsers.count - 1,
              !isLoading,
              !isFollowingLoading,
              !isLoadingMoreFollowing,
              canLoadMoreFollowing else {
            return
        }

        guard let cursor = nextFollowingMaxId?.nilIfEmpty else {
            canLoadMoreFollowing = false
            return
        }

        guard let userName = profile?.userName?.trimmingPrefix("@").nilIfEmpty else {
            canLoadMoreFollowing = false
            return
        }

        isLoadingMoreFollowing = true
        defer { isLoadingMoreFollowing = false }

        do {
            let page = try await appState.fetchUserFollowing(userName: userName, maxId: cursor)
            appendUniqueUsers(page.data, to: &followingUsers)
            await refreshRelationships(for: page.data)
            nextFollowingMaxId = page.maxId
            canLoadMoreFollowing = page.maxId != nil && !page.data.isEmpty
            followingErrorMessage = nil
        } catch {
            followingErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    @MainActor
    private func loadMoreFollowersIfNeeded(currentIndex: Int) async {
        guard selectedContentTab == .followers,
              currentIndex == followersUsers.count - 1,
              !isLoading,
              !isFollowersLoading,
              !isLoadingMoreFollowers,
              canLoadMoreFollowers else {
            return
        }

        guard let cursor = nextFollowersMaxId?.nilIfEmpty else {
            canLoadMoreFollowers = false
            return
        }

        guard let userName = profile?.userName?.trimmingPrefix("@").nilIfEmpty else {
            canLoadMoreFollowers = false
            return
        }

        isLoadingMoreFollowers = true
        defer { isLoadingMoreFollowers = false }

        do {
            let page = try await appState.fetchUserFollowers(userName: userName, maxId: cursor)
            appendUniqueUsers(page.data, to: &followersUsers)
            await refreshRelationships(for: page.data)
            nextFollowersMaxId = page.maxId
            canLoadMoreFollowers = page.maxId != nil && !page.data.isEmpty
            followersErrorMessage = nil
        } catch {
            followersErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func appendUniqueStatuses(_ incoming: [Status]) {
        guard !incoming.isEmpty else {
            return
        }

        let existingIds = Set(statuses.map(\.id))
        let uniqueIncoming = incoming.filter { !existingIds.contains($0.id) }
        statuses.append(contentsOf: uniqueIncoming)
    }

    private func appendUniqueUsers(_ incoming: [User], to destination: inout [User]) {
        guard !incoming.isEmpty else {
            return
        }

        var existingKeys = Set(destination.map(\.uniquenessKey))
        let uniqueIncoming = incoming.filter { existingKeys.insert($0.uniquenessKey).inserted }
        destination.append(contentsOf: uniqueIncoming)
    }

    @MainActor
    private func refreshRelationships(for users: [User]) async {
        let userIds = Array(Set(users.compactMap { $0.id?.nilIfEmpty }))
        guard !userIds.isEmpty else {
            return
        }

        do {
            let relationships = try await appState.fetchRelationships(userIds: userIds)
            for relationship in relationships {
                if let userId = relationship.userId?.nilIfEmpty {
                    relationshipsByUserID[userId] = relationship
                }
            }
        } catch {
            // We can still show the list without relationship controls.
        }
    }

    @MainActor
    private func loadLatestFollowers(for userName: String?) async {
        guard let userName = userName?.trimmingPrefix("@").nilIfEmpty else {
            latestFollowers = []
            return
        }

        do {
            latestFollowers = try await appState.fetchLatestFollowers(userName: userName, limit: 10)
        } catch {
            latestFollowers = []
        }
    }
    
    private var profileShareURLObject: URL? {
        guard let profileShareURL = profileShareURL?.nilIfEmpty else {
            return nil
        }

        return URL(string: profileShareURL)
    }
}
