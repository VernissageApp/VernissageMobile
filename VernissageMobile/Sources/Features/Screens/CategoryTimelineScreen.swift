//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct CategoryTimelineScreen: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: CategoryTimelineViewModel

    private let categoryName: String

    init(categoryName: String) {
        self.categoryName = categoryName
        _viewModel = StateObject(wrappedValue: CategoryTimelineViewModel(categoryName: categoryName))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if viewModel.isLoading && viewModel.statuses.isEmpty {
                    ProgressView()
                        .tint(.primary)
                        .padding(.top, 4)
                } else if viewModel.errorMessage != nil, viewModel.statuses.isEmpty {
                    ContentUnavailableView("Cannot load category",
                                           systemImage: "exclamationmark.triangle",
                                           description: Text("Please try again in a moment."))
                        .padding(.horizontal, 16)
                } else if viewModel.photoStatuses.isEmpty {
                    ContentUnavailableView("No photos for this category",
                                           systemImage: "tag",
                                           description: Text("There are no statuses with photo attachments for \(categoryName)."))
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
        .navigationTitle(categoryName)
        .navigationBarTitleDisplayMode(.inline)
        .onFirstAppear {
            await viewModel.load(using: appState)
        }
        .refreshable {
            HapticFeedbackHelper.timelineRefreshStarted()
            await viewModel.load(using: appState, forceRefresh: true)
        }
        .errorAlertToast(Binding(
            get: { viewModel.errorMessage },
            set: { viewModel.errorMessage = $0 }
        ))
    }
}
