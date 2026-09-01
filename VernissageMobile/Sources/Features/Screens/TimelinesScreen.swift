//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct TimelinesScreen: View {
    @Environment(AppState.self) private var appState
    @State private var privateViewModel = TimelineViewModel(kind: .privateHome)
    @State private var localViewModel = TimelineViewModel(kind: .local)
    @State private var globalViewModel = TimelineViewModel(kind: .global)
    @State private var completedInitialLoads: Set<TimelineSelection> = []
    @State private var viewModelsAccountID: UUID?
    @State private var isShowingProfile = false
    @State private var refreshFeedbackTrigger = false
    @State private var showAddSheet = false

    @Binding private var selectedTimeline: TimelineSelection
    @Binding private var showAccountSwitcher: Bool

    init(selectedTimeline: Binding<TimelineSelection>,
         showAccountSwitcher: Binding<Bool>) {
        _selectedTimeline = selectedTimeline
        _showAccountSwitcher = showAccountSwitcher
    }
    
    var body: some View {
        @Bindable var bindablePrivateViewModel = privateViewModel
        @Bindable var bindableLocalViewModel = localViewModel
        @Bindable var bindableGlobalViewModel = globalViewModel

        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    Picker("Timeline", selection: $selectedTimeline) {
                        ForEach(TimelineSelection.allCases, id: \.self) { item in
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

                    if activeViewModel.statuses.isEmpty && (!activeHasCompletedInitialLoad || activeViewModel.isLoading) {
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
                                if status.id == activeViewModel.caughtUpMarkerStatusID {
                                    TimelineCaughtUpView()
                                }

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
            .navigationTitle(selectedTimeline.navigationTitle)
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
            .task(id: timelineLoadTaskID) {
                await loadSelectedTimelineIfNeeded()
            }
            .refreshable {
                await refreshSelectedTimeline()
            }
            .errorAlertToast($bindablePrivateViewModel.errorMessage)
            .errorAlertToast($bindableLocalViewModel.errorMessage)
            .errorAlertToast($bindableGlobalViewModel.errorMessage)
            .sensoryFeedback(.impact, trigger: refreshFeedbackTrigger)
        }
        .id(appState.activeAccountID)
        .sheet(isPresented: $showAddSheet) {
            AddStatusPlaceholderSheet()
        }
    }

    private var timelineLoadTaskID: String {
        "\(appState.activeAccountID?.uuidString ?? "no-account"):\(selectedTimeline.rawValue)"
    }

    private var activeViewModel: TimelineViewModel {
        viewModel(for: selectedTimeline)
    }

    private func viewModel(for timeline: TimelineSelection) -> TimelineViewModel {
        switch timeline {
        case .privateHome:
            privateViewModel
        case .local:
            localViewModel
        case .global:
            globalViewModel
        }
    }

    private var activeHasCompletedInitialLoad: Bool {
        completedInitialLoads.contains(selectedTimeline)
    }

    private func loadSelectedTimelineIfNeeded() async {
        let accountID = appState.activeAccountID
        if viewModelsAccountID != accountID {
            resetTimelines()
            viewModelsAccountID = accountID
        }

        let timeline = selectedTimeline
        guard !completedInitialLoads.contains(timeline) else {
            return
        }

        let timelineViewModel = viewModel(for: timeline)
        await timelineViewModel.load(using: appState)

        guard !Task.isCancelled, appState.activeAccountID == accountID else {
            return
        }

        completedInitialLoads.insert(timeline)
    }

    private func refreshSelectedTimeline() async {
        let accountID = appState.activeAccountID
        let timeline = selectedTimeline
        let timelineViewModel = viewModel(for: timeline)

        await timelineViewModel.load(using: appState, forceRefresh: true)

        guard !Task.isCancelled, appState.activeAccountID == accountID else {
            return
        }

        completedInitialLoads.insert(timeline)
        refreshFeedbackTrigger.toggle()
    }

    private func resetTimelines() {
        privateViewModel = TimelineViewModel(kind: .privateHome)
        localViewModel = TimelineViewModel(kind: .local)
        globalViewModel = TimelineViewModel(kind: .global)
        completedInitialLoads = []
    }
}
