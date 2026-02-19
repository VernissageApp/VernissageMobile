//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct OtherTimelineScreen: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var localViewModel = TimelineViewModel(kind: .local)
    @StateObject private var globalViewModel = TimelineViewModel(kind: .global)
    @State private var isShowingProfile = false
    @State private var showAddSheet = false

    @Binding private var selectedTimeline: OtherTimelineSelection
    @Binding private var showAccountSwitcher: Bool

    init(selectedTimeline: Binding<OtherTimelineSelection>,
         showAccountSwitcher: Binding<Bool>) {
        _selectedTimeline = selectedTimeline
        _showAccountSwitcher = showAccountSwitcher
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    Picker("Other timeline", selection: $selectedTimeline) {
                        ForEach(OtherTimelineSelection.allCases, id: \.self) { item in
                            Text(item.label).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 2)

                    Text(selectedTimeline.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)

                    if activeViewModel.isLoading && activeViewModel.statuses.isEmpty {
                        ProgressView()
                            .tint(.primary)
                    } else if activeViewModel.errorMessage != nil, activeViewModel.statuses.isEmpty {
                        ContentUnavailableView("Cannot load timeline",
                                               systemImage: "exclamationmark.triangle",
                                               description: Text("Please try again in a moment."))
                            .foregroundStyle(.secondary)
                    } else if activeViewModel.photoStatuses.isEmpty {
                        ContentUnavailableView("No photos yet",
                                               systemImage: "photo.on.rectangle.angled",
                                               description: Text("This timeline has no statuses with photo attachments."))
                            .foregroundStyle(.secondary)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(activeViewModel.photoStatuses, id: \.id) { status in
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
                                        await activeViewModel.loadMoreIfNeeded(
                                            using: appState,
                                            currentStatusID: status.id
                                        )
                                    }
                                }
                            }

                            if activeViewModel.isLoadingMore {
                                ProgressView()
                                    .tint(.primary)
                                    .padding(.vertical, 12)
                            }
                        }
                    }
                }
            }
            .navigationTitle(selectedTimeline.kind == .local ? "Local timeline": "Global timeline")
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
            .onFirstAppear(id: selectedTimeline) {
                await activeViewModel.load(using: appState, forceRefresh: true)
            }
            .refreshable {
                HapticFeedbackHelper.timelineRefreshStarted()
                await activeViewModel.load(using: appState, forceRefresh: true)
            }
            .errorAlertToast(Binding(
                get: { localViewModel.errorMessage },
                set: { localViewModel.errorMessage = $0 }
            ))
            .errorAlertToast(Binding(
                get: { globalViewModel.errorMessage },
                set: { globalViewModel.errorMessage = $0 }
            ))
        }
        .id(appState.activeAccountID)
        .sheet(isPresented: $showAddSheet) {
            AddStatusPlaceholderSheet()
        }
    }

    private var activeViewModel: TimelineViewModel {
        selectedTimeline == .local ? localViewModel : globalViewModel
    }
}
