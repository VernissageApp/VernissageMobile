//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct DirectConversationScreen: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: DirectConversationViewModel
    @State private var messageToDelete: DirectMessage?
    @State private var showsDeleteConfirmation = false
    @State private var isVisible = false
    @State private var mentionedUserRoute: MentionedUserRoute?
    @State private var hashtagTimelineRoute: HashtagTimelineRoute?
    @State private var profileLinkURL: URL?
    @State private var attachmentSelection: DirectMessageAttachmentSelection?

    init(conversation: DirectConversation?, conversationID: String? = nil) {
        _model = State(initialValue: DirectConversationViewModel(conversation: conversation, conversationID: conversationID))
    }

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            DirectMessageRecipientsView(model: model)

            if !model.isDraft {
                Divider()
            }

            // Drafts have no history, so recipient search can use the remaining space above the composer.
            if !model.isDraft || model.searchResults.isEmpty {
                history
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            DirectMessageComposerView(model: model)
        }
        .navigationTitle(model.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if model.conversation != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(model.conversation?.isMuted == true ? "Unmute conversation" : "Mute conversation",
                               systemImage: model.conversation?.isMuted == true ? "bell" : "bell.slash") {
                            Task {
                                await model.toggleMute(using: appState)
                            }
                        }
                        .disabled(model.isMuting)
                    } label: {
                        Label("Conversation options", systemImage: "ellipsis")
                    }
                }
            }
        }
        .confirmationDialog("Delete this message?", isPresented: $showsDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete message", role: .destructive) {
                if let messageToDelete {
                    Task {
                        await model.delete(messageToDelete, using: appState)
                    }
                }
            }
        }
        .fullScreenCover(item: $attachmentSelection) { selection in
            DirectMessageAttachmentSheet(selection: selection)
        }
        .navigationDestination(item: $mentionedUserRoute) { route in
            UserProfileScreen(userName: route.userName, preferredDisplayName: route.preferredDisplayName)
        }
        .navigationDestination(item: $hashtagTimelineRoute) { route in
            HashtagTimelineScreen(hashtagName: route.hashtagName)
        }
        .errorAlertToast($model.errorMessage)
        .onAppear {
            isVisible = true
        }
        .onDisappear {
            isVisible = false

            // Keep draft uploads while a photo, profile, or hashtag destination covers the conversation.
            if attachmentSelection == nil, mentionedUserRoute == nil, hashtagTimelineRoute == nil {
                Task {
                    await model.discardAttachments(using: appState)
                }
            }
        }
        .task {
            // Preparing the conversation must finish independently of polling lifecycle changes.
            if model.isReady {
                await model.loadMessages(using: appState)
            } else {
                await model.prepare(using: appState)
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

                // Retry initialization after a transient failure before polling an established conversation.
                if model.isReady {
                    await model.loadMessages(using: appState, reportErrors: false)
                } else {
                    await model.prepare(using: appState)
                }
            }
        }
        .task(id: profileLinkURL) {
            guard let url = profileLinkURL,
                  let userName = MarkdownLinkResolver.userName(from: url) else {
                return
            }

            let accountID = appState.activeAccountID

            defer {
                if profileLinkURL == url {
                    profileLinkURL = nil
                }
            }

            do {
                let route = try await MarkdownLinkResolver.profileRoute(userName: userName, using: appState)

                guard !Task.isCancelled, appState.activeAccountID == accountID else {
                    return
                }

                if let route {
                    mentionedUserRoute = route
                    return
                }
            } catch {
                // Unresolved profiles fall back to their original web URL, matching status links.
            }

            guard !Task.isCancelled, appState.activeAccountID == accountID else {
                return
            }

            openURL(url)
        }
        .task(id: model.userQuery) {
            await model.searchUsers(using: appState)
        }
        .task(id: model.readTaskKey + "\(isVisible && scenePhase == .active)") {
            guard isVisible, scenePhase == .active else {
                return
            }

            do {
                try await Task.sleep(for: .milliseconds(250))
            } catch {
                return
            }

            await model.markVisibleRead(using: appState)
        }
    }

    private var history: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if model.hasMore {
                        Button("Load older messages") {
                            Task {
                                await model.loadMessages(using: appState, more: true)
                            }
                        }
                        .buttonStyle(.glass)
                        .disabled(model.isLoading)
                    }

                    if model.isPreparing || model.isLoading {
                        ProgressView()
                    }

                    if !model.isReady && !model.isPreparing && !model.isLoading {
                        Button("Retry") {
                            Task {
                                await model.prepare(using: appState)
                            }
                        }
                            .buttonStyle(.glass)
                    }

                    ForEach(model.messages) { message in
                        DirectMessageBubbleView(
                            message: message, isOwn: message.sender?.id == model.currentUserID,
                            isActionPending: model.pendingActions.contains(message.id),
                            onOpenMarkdownURL: handleMessageMarkdownURL,
                            onLike: {
                                Task {
                                    await model.toggleLike(message, using: appState)
                                }
                            },
                            onDelete: {
                                messageToDelete = message
                                showsDeleteConfirmation = true
                            },
                            onOpenAttachment: { attachments, index in
                                attachmentSelection = DirectMessageAttachmentSelection(attachments: attachments, initialIndex: index)
                            }
                        )
                        .id(message.id)
                    }
                }
                .scrollTargetLayout()
                .padding()
            }
            .defaultScrollAnchor(.bottom, for: .initialOffset)
            .scrollDismissesKeyboard(.interactively)
            .onScrollTargetVisibilityChange(idType: String.self) { ids in
                model.visibleMessageIDs = ids
            }
            .onChange(of: model.messages.last?.id) { oldID, newID in
                // Follow incoming messages only when the previous latest message was visible or history was empty.
                if let newID, oldID == nil || oldID.map({ model.visibleMessageIDs.contains($0) }) == true {
                    proxy.scrollTo(newID, anchor: .bottom)
                }
            }
            .onChange(of: model.scrollRequest) {
                if let id = model.messages.last?.id {
                    proxy.scrollTo(id, anchor: .bottom)
                }
            }
            .refreshable {
                await model.loadMessages(using: appState)
            }
        }
    }

    private func handleMessageMarkdownURL(_ url: URL) -> OpenURLAction.Result {
        if let hashtag = MarkdownLinkResolver.hashtagName(from: url) {
            hashtagTimelineRoute = HashtagTimelineRoute(hashtagName: hashtag)
            return .handled
        }

        if MarkdownLinkResolver.userName(from: url) != nil {
            profileLinkURL = url
            return .handled
        }

        return .systemAction
    }

}
