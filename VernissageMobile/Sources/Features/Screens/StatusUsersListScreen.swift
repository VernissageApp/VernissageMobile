//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct StatusUsersListScreen: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = StatusUsersListViewModel()

    let statusId: String
    let kind: StatusUsersListKind

    var body: some View {
        ScrollView {
            ProfileUsersListView(users: viewModel.users,
                                 isLoading: viewModel.isLoading,
                                 isLoadingMore: viewModel.isLoadingMore,
                                 errorMessage: viewModel.errorMessage,
                                 emptyTitle: kind.emptyTitle,
                                 emptyDescription: kind.emptyDescription) { currentIndex in
                Task {
                    await viewModel.loadMoreIfNeeded(using: appState,
                                                     statusId: statusId,
                                                     kind: kind,
                                                     currentIndex: currentIndex)
                }
            }
            .padding(.top, 8)
        }
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .onFirstAppear {
            await viewModel.load(using: appState, statusId: statusId, kind: kind, forceRefresh: true)
        }
        .refreshable {
            await viewModel.load(using: appState, statusId: statusId, kind: kind, forceRefresh: true)
        }
        .errorAlertToast(Binding(
            get: { viewModel.errorMessage },
            set: { viewModel.errorMessage = $0 }
        ))
    }
}
