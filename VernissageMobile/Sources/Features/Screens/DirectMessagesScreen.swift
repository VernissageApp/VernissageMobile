//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct DirectMessagesScreen: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = DirectMessagesViewModel()

    var body: some View {
        @Bindable var model = model

        List {
            Section {
                Label(AppConstants.DirectMessages.privacyNotice, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                ForEach(model.filteredConversations) { conversation in
                    NavigationLink {
                        DirectConversationScreen(conversation: conversation)
                    } label: {
                        DirectConversationRowView(conversation: conversation, currentUserID: model.currentUserID)
                    }
                }

                if model.hasMore {
                    Button("Load more conversations") {
                        Task {
                            await model.load(using: appState, more: true)
                        }
                    }
                    .disabled(model.isLoading)
                }

                if model.isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                }

                if model.didLoad && model.filteredConversations.isEmpty {
                    ContentUnavailableView(
                        model.query.isEmpty ? "No conversations yet" : "No matching conversations",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Use the plus button to start a conversation.")
                    )
                }
            }
        }
        .navigationTitle(AppConstants.DirectMessages.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    DirectConversationScreen(conversation: nil)
                } label: {
                    Label("New conversation", systemImage: "plus")
                        .labelStyle(.iconOnly)
                }
            }
        }
        .searchable(text: $model.query, prompt: "Search conversations")
        .refreshable {
            await model.load(using: appState)
        }
        .errorAlertToast($model.errorMessage)
        .task {
            // Keep the initial request independent of visibility changes that can cancel and restart polling.
            if !model.didLoad {
                await model.load(using: appState)
            } else {
                await model.refresh(using: appState)
            }
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else {
                return
            }

            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: AppConstants.DirectMessages.refreshInterval)
                } catch {
                    return
                }

                await model.refresh(using: appState)
            }
        }
    }
}
