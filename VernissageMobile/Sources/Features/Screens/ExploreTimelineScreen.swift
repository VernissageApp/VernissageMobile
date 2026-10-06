//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ExploreTimelineScreen: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: ExploreTimelineViewModel
    @State private var refreshFeedbackTrigger = false

    private let item: ExploreItem
    private let selection: ExploreContentSelection

    init(item: ExploreItem, selection: ExploreContentSelection) {
        self.item = item
        self.selection = selection
        _viewModel = State(initialValue: ExploreTimelineViewModel(item: item, selection: selection))
    }

    var body: some View {
        @Bindable var bindableViewModel = viewModel

        ScrollView {
            LazyVStack(spacing: 8) {
                if viewModel.isLoading && viewModel.statuses.isEmpty {
                    ProgressView()
                        .tint(.primary)
                        .padding(.top, 4)
                } else if viewModel.errorMessage != nil, viewModel.statuses.isEmpty {
                    ContentUnavailableView(
                        "Cannot load \(selection.singularTitle)",
                        systemImage: "exclamationmark.triangle",
                        description: Text("Please try again in a moment.")
                    )
                    .padding(.horizontal, 16)
                } else if viewModel.photoStatuses.isEmpty {
                    ContentUnavailableView(
                        "No photos for this \(selection.singularTitle)",
                        systemImage: selection.emptySystemImage,
                        description: Text("There are no statuses with photo attachments for \(item.name).")
                    )
                    .padding(.horizontal, 16)
                } else {
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
                            await viewModel.loadMoreIfNeeded(using: appState, currentStatusID: status.id)
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
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .onFirstAppear {
            await viewModel.load(using: appState)
        }
        .refreshable {
            await viewModel.load(using: appState, forceRefresh: true)

            guard !Task.isCancelled else {
                return
            }

            refreshFeedbackTrigger.toggle()
        }
        .errorAlertToast($bindableViewModel.errorMessage)
        .sensoryFeedback(.impact, trigger: refreshFeedbackTrigger)
    }
}
