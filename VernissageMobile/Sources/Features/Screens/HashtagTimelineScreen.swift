//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct HashtagTimelineScreen: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: HashtagTimelineViewModel
    @State private var refreshFeedbackTrigger = false

    private let hashtagName: String

    init(hashtagName: String) {
        let normalizedHashtagName = hashtagName.trimmingPrefix("#")
        self.hashtagName = normalizedHashtagName
        _viewModel = State(initialValue: HashtagTimelineViewModel(hashtagName: normalizedHashtagName))
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
                    ContentUnavailableView("Cannot load hashtag",
                                           systemImage: "exclamationmark.triangle",
                                           description: Text("Please try again in a moment."))
                        .padding(.horizontal, 16)
                } else if viewModel.photoStatuses.isEmpty {
                    ContentUnavailableView("No photos for this hashtag",
                                           systemImage: "number",
                                           description: Text("There are no statuses with photo attachments for #\(hashtagName)."))
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
        .navigationTitle("#\(hashtagName)")
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
