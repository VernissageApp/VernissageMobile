//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct TimelineScreen: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: TimelineViewModel
    @State private var hasCompletedInitialLoad = false
    @State private var isShowingProfile = false
    @State private var refreshFeedbackTrigger = false
    @State private var showAddSheet = false

    private let title: String
    private let subtitle: String
    @Binding private var showAccountSwitcher: Bool

    init(kind: TimelineKind,
         title: String,
         subtitle: String,
         showAccountSwitcher: Binding<Bool>) {
        _viewModel = State(initialValue: TimelineViewModel(kind: kind))
        self.title = title
        self.subtitle = subtitle
        _showAccountSwitcher = showAccountSwitcher
    }

    var body: some View {
        @Bindable var bindableViewModel = viewModel

        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 2)

                    if viewModel.statuses.isEmpty && (!hasCompletedInitialLoad || viewModel.isLoading) {
                        ProgressView()
                            .tint(.primary)
                    } else if viewModel.errorMessage != nil, viewModel.statuses.isEmpty {
                        ContentUnavailableView("Cannot load timeline",
                                               systemImage: "exclamationmark.triangle",
                                               description: Text("Please try again in a moment."))
                            .foregroundStyle(.secondary)
                    } else if viewModel.photoStatuses.isEmpty {
                        ContentUnavailableView("No photos yet",
                                               systemImage: "photo.on.rectangle.angled",
                                               description: Text("This timeline has no statuses with photo attachments."))
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
                                .onAppear {
                                    Task {
                                        await viewModel.loadMoreIfNeeded(using: appState, currentStatusID: status.id)
                                    }
                                }
                            }

                            if viewModel.isLoadingMore {
                                ProgressView()
                                    .tint(.primary)
                                    .padding(.vertical, 12)
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
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
                await viewModel.load(using: appState)
                hasCompletedInitialLoad = true
            }
            .refreshable {
                await viewModel.load(using: appState, forceRefresh: true)
                hasCompletedInitialLoad = true

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
}
