//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ProfileUsersListView: View {
    private enum Layout {
        static let initialLoadingPlaceholderHeight: CGFloat = 640
    }

    let users: [User]
    let isLoading: Bool
    let isLoadingMore: Bool
    let showInitialLoadingPlaceholder: Bool
    let errorMessage: String?
    let emptyTitle: String
    let emptyDescription: String
    let showFollowButtons: Bool
    let singleButton: Bool
    let relationshipsByUserID: [String: Relationship]
    let onRelationshipChanged: ((String, Relationship) -> Void)?
    let onUserAppear: (Int) -> Void

    init(
        users: [User],
        isLoading: Bool,
        isLoadingMore: Bool,
        showInitialLoadingPlaceholder: Bool = false,
        errorMessage: String?,
        emptyTitle: String,
        emptyDescription: String,
        showFollowButtons: Bool = false,
        singleButton: Bool = false,
        relationshipsByUserID: [String: Relationship] = [:],
        onRelationshipChanged: ((String, Relationship) -> Void)? = nil,
        onUserAppear: @escaping (Int) -> Void
    ) {
        self.users = users
        self.isLoading = isLoading
        self.isLoadingMore = isLoadingMore
        self.showInitialLoadingPlaceholder = showInitialLoadingPlaceholder
        self.errorMessage = errorMessage
        self.emptyTitle = emptyTitle
        self.emptyDescription = emptyDescription
        self.showFollowButtons = showFollowButtons
        self.singleButton = singleButton
        self.relationshipsByUserID = relationshipsByUserID
        self.onRelationshipChanged = onRelationshipChanged
        self.onUserAppear = onUserAppear
    }

    var body: some View {
        if users.isEmpty && errorMessage == nil && (isLoading || showInitialLoadingPlaceholder) {
            VStack(spacing: 12) {
                ProgressView()
                    .tint(.primary)
                    .padding(.top, 4)

                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: Layout.initialLoadingPlaceholderHeight)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
        } else if errorMessage != nil, users.isEmpty {
            EmptyView()
        } else if users.isEmpty {
            ContentUnavailableView(emptyTitle,
                                   systemImage: "person.3",
                                   description: Text(emptyDescription))
                .padding(.horizontal, 16)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(users.indices, id: \.self) { index in
                    let user = users[index]
                    ProfileUserRowView(
                        user: user,
                        relationship: relationship(for: user),
                        showFollowButtons: showFollowButtons,
                        singleButton: singleButton
                    ) { relationship in
                        if let userId = user.id?.nilIfEmpty {
                            onRelationshipChanged?(userId, relationship)
                        }
                    }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .onAppear {
                            onUserAppear(index)
                        }

                    if index < users.count - 1 {
                        Divider()
                            .padding(.leading, 84)
                            .padding(.trailing, 16)
                    }
                }

                if isLoadingMore {
                    ProgressView()
                        .tint(.primary)
                        .padding(.vertical, 12)
                }
            }
        }
    }

    private func relationship(for user: User) -> Relationship? {
        guard let userId = user.id?.nilIfEmpty else {
            return nil
        }

        return relationshipsByUserID[userId]
    }
}
