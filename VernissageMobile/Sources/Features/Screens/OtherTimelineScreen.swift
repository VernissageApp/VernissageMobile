//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct OtherTimelineScreen: View {
    @Environment(AppState.self) private var appState
    @State private var localViewModel = TimelineViewModel(kind: .local)
    @State private var globalViewModel = TimelineViewModel(kind: .global)
    @State private var hasCompletedInitialLocalLoad = false
    @State private var hasCompletedInitialGlobalLoad = false
    @State private var isShowingProfile = false
    @State private var refreshFeedbackTrigger = false
    @State private var showAddSheet = false

    @Binding private var selectedTimeline: OtherTimelineSelection
    @Binding private var showAccountSwitcher: Bool

    init(selectedTimeline: Binding<OtherTimelineSelection>,
         showAccountSwitcher: Binding<Bool>) {
        _selectedTimeline = selectedTimeline
        _showAccountSwitcher = showAccountSwitcher
    }
    
    var body: some View {
        @Bindable var bindableLocalViewModel = localViewModel
        @Bindable var bindableGlobalViewModel = globalViewModel

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
                await activeViewModel.load(using: appState)
                markInitialLoadCompleted(for: selectedTimeline)
            }
            .refreshable {
                await activeViewModel.load(using: appState, forceRefresh: true)
                markInitialLoadCompleted(for: selectedTimeline)

                guard !Task.isCancelled else {
                    return
                }

                refreshFeedbackTrigger.toggle()
            }
            .errorAlertToast($bindableLocalViewModel.errorMessage)
            .errorAlertToast($bindableGlobalViewModel.errorMessage)
            .sensoryFeedback(.impact, trigger: refreshFeedbackTrigger)
        }
        .id(appState.activeAccountID)
        .sheet(isPresented: $showAddSheet) {
            AddStatusPlaceholderSheet()
        }
    }

    private var activeViewModel: TimelineViewModel {
        selectedTimeline == .local ? localViewModel : globalViewModel
    }

    private var activeHasCompletedInitialLoad: Bool {
        selectedTimeline == .local ? hasCompletedInitialLocalLoad : hasCompletedInitialGlobalLoad
    }

    private func markInitialLoadCompleted(for timeline: OtherTimelineSelection) {
        switch timeline {
        case .local:
            hasCompletedInitialLocalLoad = true
        case .global:
            hasCompletedInitialGlobalLoad = true
        }
    }
}
