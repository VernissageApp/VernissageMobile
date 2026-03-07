//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct FollowButtonsSectionView: View {
    @Environment(AppState.self) private var appState

    let user: User
    let relationship: Relationship?
    let singleButton: Bool
    let onRelationshipChanged: ((Relationship) -> Void)?

    @State private var relationshipAfterAction: Relationship?
    @State private var isProcessing = false
    @State private var relationshipRefreshTask: Task<Void, Never>?

    init(
        user: User,
        relationship: Relationship?,
        singleButton: Bool,
        onRelationshipChanged: ((Relationship) -> Void)?
    ) {
        self.user = user
        self.relationship = relationship
        self.singleButton = singleButton
        self.onRelationshipChanged = onRelationshipChanged
    }

    private var updatedRelationship: Relationship? {
        relationshipAfterAction ?? relationship
    }

    private var isCurrentUser: Bool {
        guard let signedInUserName = appState.activeAccount?.userName.trimmingPrefix("@").lowercased().nilIfEmpty,
              let targetUserName = user.userName?.trimmingPrefix("@").lowercased().nilIfEmpty else {
            return false
        }

        return signedInUserName == targetUserName
    }

    private var canChangeRelationship: Bool {
        !isCurrentUser
    }

    private var shouldShowApproveReject: Bool {
        updatedRelationship?.requestedBy == true && !isCurrentUser
    }

    private var shouldShowFollowButton: Bool {
        guard let updatedRelationship else {
            return false
        }

        return !updatedRelationship.following && !updatedRelationship.requested
    }

    private var followButtonTitle: String {
        if updatedRelationship?.followedBy == true {
            return "Follow back"
        }

        return "Follow"
    }

    private var unfollowButtonTitle: String {
        if updatedRelationship?.following == true {
            return "Unfollow"
        }

        return "Cancel request"
    }

    var body: some View {
        Group {
            if canChangeRelationship {
                controlsContent
            }
        }
        .onAppear {
            relationshipAfterAction = relationship
        }
        .onChange(of: relationship?.cacheKey, initial: false) { _, _ in
            relationshipAfterAction = relationship
        }
        .onDisappear {
            relationshipRefreshTask?.cancel()
        }
    }

    @ViewBuilder
    private var controlsContent: some View {
        if isProcessing {
            ProgressView()
                .controlSize(.small)
        } else if updatedRelationship == nil {
            ProgressView()
                .controlSize(.small)
        } else if singleButton {
            singleButtonControls
        } else {
            multipleButtonsControls
        }
    }

    @ViewBuilder
    private var singleButtonControls: some View {
        if shouldShowApproveReject {
            Menu {
                Button("Accept request") {
                    Task { await approveFollow() }
                }

                Button("Reject request", role: .destructive) {
                    Task { await rejectFollow() }
                }
            } label: {
                Label("Respond", systemImage: "ellipsis.circle")
            }
            .menuStyle(.button)
            .buttonStyle(.bordered)
            .controlSize(.small)
        } else if canChangeRelationship {
            if shouldShowFollowButton {
                Button(followButtonTitle) {
                    Task { await follow() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                if updatedRelationship?.following == true {
                    Button(unfollowButtonTitle) {
                        Task { await unfollow() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .foregroundStyle(.white)
                    .controlSize(.small)
                } else {
                    Button(unfollowButtonTitle) {
                        Task { await unfollow() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    private var multipleButtonsControls: some View {
        HStack(spacing: 8) {
            if canChangeRelationship {
                if shouldShowFollowButton {
                    Button(followButtonTitle) {
                        Task { await follow() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                } else {
                    if updatedRelationship?.following == true {
                        Button(unfollowButtonTitle) {
                            Task { await unfollow() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .foregroundStyle(.white)
                        .controlSize(.regular)
                    } else {
                        Button(unfollowButtonTitle) {
                            Task { await unfollow() }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }
                }
            }

            if shouldShowApproveReject {
                Button("Accept request") {
                    Task { await approveFollow() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)

                Button("Reject request") {
                    Task { await rejectFollow() }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
    }

    @MainActor
    private func follow() async {
        guard let userName = user.userName?.trimmingPrefix("@").nilIfEmpty else {
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            let updated = try await appState.follow(userName: userName)
            updateRelationship(updated)
            startRelationshipRefreshIfNeeded(using: updated)
        } catch {
            appState.showErrorToast((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    @MainActor
    private func unfollow() async {
        guard let userName = user.userName?.trimmingPrefix("@").nilIfEmpty else {
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            let updated = try await appState.unfollow(userName: userName)
            updateRelationship(updated)
        } catch {
            appState.showErrorToast((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    @MainActor
    private func approveFollow() async {
        guard let userId = user.id?.nilIfEmpty else {
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            let updated = try await appState.approveFollowRequest(userId: userId)
            updateRelationship(updated)
        } catch {
            appState.showErrorToast((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    @MainActor
    private func rejectFollow() async {
        guard let userId = user.id?.nilIfEmpty else {
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            let updated = try await appState.rejectFollowRequest(userId: userId)
            updateRelationship(updated)
        } catch {
            appState.showErrorToast((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    @MainActor
    private func updateRelationship(_ relationship: Relationship) {
        relationshipAfterAction = relationship
        onRelationshipChanged?(relationship)
    }

    @MainActor
    private func startRelationshipRefreshIfNeeded(using relationship: Relationship) {
        relationshipRefreshTask?.cancel()

        guard relationship.requested, !relationship.following else {
            return
        }

        guard let userId = user.id?.nilIfEmpty else {
            return
        }

        relationshipRefreshTask = Task {
            for _ in 0..<10 {
                try? await Task.sleep(for: .milliseconds(2500))
                guard !Task.isCancelled else {
                    return
                }

                do {
                    let refreshed = try await appState.fetchRelationship(userId: userId)
                    await MainActor.run {
                        updateRelationship(refreshed)
                    }

                    if refreshed.following {
                        return
                    }
                } catch {
                    // Keep retrying until we hit max attempts.
                }
            }
        }
    }
}
