//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct FollowButtonsSectionView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    let user: User
    let relationship: Relationship?
    let singleButton: Bool
    let isCompact: Bool
    let onRelationshipChanged: ((Relationship) -> Void)?

    @State private var relationshipAfterAction: Relationship?
    @State private var isProcessing = false
    @State private var relationshipRefreshTask: Task<Void, Never>?

    init(
        user: User,
        relationship: Relationship?,
        singleButton: Bool,
        isCompact: Bool = false,
        onRelationshipChanged: ((Relationship) -> Void)?
    ) {
        self.user = user
        self.relationship = relationship
        self.singleButton = singleButton
        self.isCompact = isCompact
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

    private var actionButtonBackgroundColor: Color {
        colorScheme == .dark ? .black : .white
    }

    private var actionButtonFont: Font {
        isCompact ? .footnote : .body
    }

    private var actionButtonMinHeight: CGFloat {
        isCompact ? 24 : 30
    }

    private var actionButtonHorizontalPadding: CGFloat {
        isCompact ? 8 : 12
    }

    private var actionButtonCornerRadius: CGFloat {
        isCompact ? 12 : 14
    }

    private var actionButtonBorderWidth: CGFloat {
        isCompact ? 1 : 1.5
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
            .tint(.secondary)
            .controlSize(isCompact ? .mini : .small)
        } else if canChangeRelationship {
            if shouldShowFollowButton {
                relationshipActionButton(followButtonTitle, borderColor: .blue, action: follow)
            } else if updatedRelationship?.following == true {
                relationshipActionButton(unfollowButtonTitle, borderColor: .red, action: unfollow)
            } else {
                relationshipActionButton(unfollowButtonTitle, borderColor: .orange, action: unfollow)
            }
        }
    }

    private var multipleButtonsControls: some View {
        HStack(spacing: 8) {
            if canChangeRelationship {
                if shouldShowFollowButton {
                    relationshipActionButton(followButtonTitle, borderColor: .blue, action: follow)
                } else if updatedRelationship?.following == true {
                    relationshipActionButton(unfollowButtonTitle, borderColor: .red, action: unfollow)
                } else {
                    relationshipActionButton(unfollowButtonTitle, borderColor: .orange, action: unfollow)
                }
            }

            if shouldShowApproveReject {
                relationshipActionButton("Accept request", borderColor: .green, action: approveFollow)
                relationshipActionButton("Reject request", borderColor: .orange, action: rejectFollow)
            }
        }
    }

    private func relationshipActionButton(
        _ title: String,
        borderColor: Color,
        action: @escaping @MainActor () async -> Void
    ) -> some View {
        Button {
            Task { await action() }
        } label: {
            Text(title)
                .font(actionButtonFont)
                .bold()
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(minHeight: actionButtonMinHeight)
                .padding(.horizontal, actionButtonHorizontalPadding)
        }
        .buttonStyle(.plain)
        .foregroundStyle(borderColor)
        .background {
            RoundedRectangle(cornerRadius: actionButtonCornerRadius)
                .fill(actionButtonBackgroundColor)
        }
        .overlay {
            RoundedRectangle(cornerRadius: actionButtonCornerRadius)
                .stroke(borderColor, lineWidth: actionButtonBorderWidth)
        }
        .contentShape(.rect)
        .accessibilityAddTraits(.isButton)
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
