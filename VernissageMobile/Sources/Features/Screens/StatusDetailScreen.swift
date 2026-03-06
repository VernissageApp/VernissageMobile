//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

#if canImport(Translation)
import Translation
#endif

struct StatusDetailScreen: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage(AppConstants.StorageKeys.settingsShowAlternativeText) private var showAlternativeText = false

    @State private var displayedStatus: Status
    @State private var selectedAttachmentIndex = 0
    @State private var mediaContentWidth: CGFloat = 0
    @State private var isBoostProcessing = false
    @State private var isFavouriteProcessing = false
    @State private var isBookmarkProcessing = false
    @State private var isFeatureProcessing = false
    @State private var actionErrorMessage: String?

    @State private var comments: [StatusCommentItem] = []
    @State private var isCommentsLoading = false
    @State private var commentsErrorMessage: String?
    @State private var replySheetTarget: ReplySheetTarget?
    @State private var replyText = ""
    @State private var isSendingReply = false
    @FocusState private var isReplyFieldFocused: Bool
    @State private var presentedUsersListKind: StatusUsersListKind?
    @State private var categoryTimelineRoute: CategoryTimelineRoute?
    @State private var hashtagTimelineRoute: HashtagTimelineRoute?
    @State private var mentionedUserRoute: MentionedUserRoute?
    @State private var showDeleteStatusConfirmation = false
    @State private var reportSheetStatus: Status?
    @State private var isShowingApplyContentWarningSheet = false
    @State private var isShowingTranslateSheet = false
    @State private var translationSourceText = ""
    @State private var statusForEditing: Status?
    @State private var isAttachmentViewerPresented = false
    @State private var attachmentViewerInitialIndex = 0
    private let boostedByUser: User?

    private let maxCommentLength = 500

    init(status: Status) {
        _displayedStatus = State(initialValue: status.mainStatus)
        boostedByUser = status.reblog != nil ? status.user : nil
    }

    var body: some View {
        statusDetailAlertsLayer
    }

    private var statusDetailBaseLayer: some View {
        ScrollView {
            statusDetailContent
        }
        .id(displayedStatus.id)
        .navigationTitle(displayedStatus.hasMultipleAttachments ? "Photos" : "Photo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                statusMoreMenu
            }
        }
        .onFirstAppear {
            await loadStatusDetail()
        }
        .onChange(of: displayableAttachments.count, initial: false) { _, count in
            guard count > 0 else {
                selectedAttachmentIndex = 0
                return
            }

            selectedAttachmentIndex = min(selectedAttachmentIndex, count - 1)
        }
    }

    private var statusDetailSheetsLayer: some View {
        statusDetailBaseLayer
            .sheet(item: $replySheetTarget) { target in
                replyComposerSheet(for: target)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $reportSheetStatus) { reportStatus in
                StatusReportSheet(status: reportStatus)
                    .presentationDetents([.fraction(0.58), .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isShowingApplyContentWarningSheet) {
                StatusContentWarningSheet(initialContentWarning: displayedStatus.contentWarning ?? "") { contentWarning in
                    try await appState.applyContentWarning(statusId: displayedStatus.id, contentWarning: contentWarning)
                    displayedStatus = try await appState.fetchStatus(statusId: displayedStatus.id)
                }
                .presentationDetents([.fraction(0.5), .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $statusForEditing) { editableStatus in
                StatusComposeScreen(mode: .edit(status: editableStatus), onStatusSaved: { savedStatus in
                    displayedStatus = savedStatus
                    Task {
                        await loadComments()
                    }
                })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
    }

    private var statusDetailNavigationLayer: some View {
        statusDetailSheetsLayer
            .fullScreenCover(isPresented: $isAttachmentViewerPresented) {
                StatusAttachmentViewerScreen(
                    attachments: displayableAttachments,
                    initialIndex: attachmentViewerInitialIndex
                )
            }
            .navigationDestination(item: $presentedUsersListKind) { kind in
                StatusUsersListScreen(statusId: displayedStatus.id, kind: kind)
            }
            .navigationDestination(item: $categoryTimelineRoute) { route in
                CategoryTimelineScreen(categoryName: route.categoryName)
            }
            .navigationDestination(item: $hashtagTimelineRoute) { route in
                HashtagTimelineScreen(hashtagName: route.hashtagName)
            }
            .navigationDestination(item: $mentionedUserRoute) { route in
                UserProfileScreen(userName: route.userName, preferredDisplayName: route.preferredDisplayName)
            }
    }

    private var statusDetailAlertsLayer: some View {
        statusDetailNavigationLayer
            .alert("Delete status?", isPresented: $showDeleteStatusConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteDisplayedStatus()
                    }
                }
            } message: {
                Text("Are you sure you want to delete this status? This action cannot be undone.")
            }
            .errorAlertToast($actionErrorMessage)
            .errorAlertToast($commentsErrorMessage)
            .translationPresentation(isPresented: $isShowingTranslateSheet, text: translationSourceText)
    }

    private var statusDetailContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            attachmentsSection
            statusActionsSection
            statusInformationSection
            commentsSection
        }
        .padding(16)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        updateMediaContentWidth(from: proxy.size.width)
                    }
                    .onChange(of: proxy.size.width) { _, newWidth in
                        updateMediaContentWidth(from: newWidth)
                    }
            }
        }
    }

    @ViewBuilder
    private var attachmentsSection: some View {
        if displayableAttachments.count > 1 {
            TabView(selection: $selectedAttachmentIndex) {
                ForEach(Array(displayableAttachments.enumerated()), id: \.offset) { index, attachment in
                    statusAttachmentView(for: attachment, fixedHeight: multiAttachmentHeight)
                        .tag(index)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            openAttachmentViewer(at: index)
                        }
                }
            }
            .frame(height: multiAttachmentHeight)
            .animation(.spring(response: 0.5, dampingFraction: 0.88), value: multiAttachmentHeight)
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .indexViewStyle(.page(backgroundDisplayMode: .automatic))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else if let attachment = displayableAttachments.first {
            statusAttachmentView(for: attachment, fixedHeight: singleAttachmentHeight)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentShape(Rectangle())
                .onTapGesture {
                    openAttachmentViewer(at: 0)
                }
        }
    }

    private var statusActionsSection: some View {
        HStack(spacing: 10) {
            statusActionButton(
                systemName: displayedStatus.reblogged == true ? "arrow.2.squarepath" : "arrow.2.squarepath",
                isActive: displayedStatus.reblogged == true,
                isDisabled: isBoostProcessing,
                accessibilityLabel: displayedStatus.reblogged == true ? "Unboost" : "Boost"
            ) {
                Task { await toggleReblog() }
            }

            statusActionButton(
                systemName: displayedStatus.favourited == true ? "star.fill" : "star",
                isActive: displayedStatus.favourited == true,
                isDisabled: isFavouriteProcessing,
                accessibilityLabel: displayedStatus.favourited == true ? "Unfavourite" : "Favourite"
            ) {
                Task { await toggleFavourite() }
            }

            statusActionButton(
                systemName: displayedStatus.bookmarked == true ? "bookmark.fill" : "bookmark",
                isActive: displayedStatus.bookmarked == true,
                isDisabled: isBookmarkProcessing,
                accessibilityLabel: displayedStatus.bookmarked == true ? "Unbookmark" : "Bookmark"
            ) {
                Task { await toggleBookmark() }
            }

            if canFeatureStatus {
                statusActionButton(
                    systemName: displayedStatus.featured == true ? "star.circle.fill" : "star.circle",
                    isActive: displayedStatus.featured == true,
                    isDisabled: isFeatureProcessing,
                    accessibilityLabel: displayedStatus.featured == true ? "Unfeature" : "Feature"
                ) {
                    Task { await toggleFeature() }
                }
            } else if let shareURLString = displayedStatus.shareURL?.nilIfEmpty,
                      let shareURL = URL(string: shareURLString) {
                ShareLink(item: shareURL) {
                    statusActionTileIcon(systemName: "square.and.arrow.up", isActive: false)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Share")
            }
        }
    }

    private var statusInformationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let boostedByUser {
                StatusBoostedByView(user: boostedByUser)
            }

            if let userName = displayedStatus.user?.userName?.trimmingPrefix("@").nilIfEmpty {
                NavigationLink {
                    UserProfileScreen(userName: userName, preferredDisplayName: displayedStatus.user?.name?.nilIfEmpty)
                } label: {
                    statusAuthorHeader
                }
                .buttonStyle(.plain)
            } else {
                statusAuthorHeader
            }

            if let warning = displayedStatus.contentWarning?.nilIfEmpty {
                Text("CW: \(warning)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
            } else if displayedStatus.sensitive == true {
                Text("CW: (empty)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
            }

            if let markdown = displayedStatus.markdownNote?.nilIfEmpty {
                MarkdownFormattedTextView(markdown)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .environment(\.openURL, OpenURLAction { url in
                        handleStatusMarkdownURL(url)
                    })
            } else if let noteForDisplay = displayedStatus.noteForDisplay, noteForDisplay.isEmpty == false {
                Text("Cannot render text status.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                Text("No text for this status.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            if let attachment = selectedAttachmentForMetadata,
               attachment.hasDisplayableMetadata ||
               selectedAttachmentAltTextForDisplay != nil ||
               statusCategoryName != nil {
                AttachmentMetadataSectionView(
                    attachment: attachment,
                    altText: selectedAttachmentAltTextForDisplay,
                    categoryName: statusCategoryName,
                    onCategoryTap: {
                        guard let categoryName = statusCategoryName else {
                            return
                        }

                        categoryTimelineRoute = CategoryTimelineRoute(categoryName: categoryName)
                    }
                )
            }

            HStack(spacing: 14) {
                Label("\(displayedStatus.favouritesCount ?? 0)", systemImage: "star")
                Label("\(displayedStatus.reblogsCount ?? 0)", systemImage: "arrow.2.squarepath")
                Label("\(displayedStatus.repliesCount ?? 0)", systemImage: "bubble.right")
                Spacer(minLength: 8)
                if let statusDate = displayedStatus.displayDate {
                    Label(statusDate.shortDateAndTimeLabel, systemImage: "calendar")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 8)
        }
        .padding(14)
        .liquidGlassCard()
    }

    private func statusActionButton(
        systemName: String,
        isActive: Bool,
        isDisabled: Bool,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            statusActionTileIcon(systemName: systemName, isActive: isActive)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(accessibilityLabel)
    }

    private func statusActionTileIcon(systemName: String, isActive: Bool) -> some View {
        Image(systemName: systemName)
            .font(.title2)
            .foregroundStyle(isActive ? .blue : .primary)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.secondary.opacity(0.12))
            )
    }

    private var displayableAttachments: [Attachment] {
        let attachments = displayedStatus.attachments ?? []
        let withImages = attachments.filter { $0.smallImageURL != nil }

        if withImages.isEmpty, let primaryAttachment = displayedStatus.primaryAttachment {
            return [primaryAttachment]
        }

        return withImages
    }

    private var selectedAttachmentForMetadata: Attachment? {
        guard !displayableAttachments.isEmpty else {
            return displayedStatus.primaryAttachment
        }

        let safeIndex = min(max(selectedAttachmentIndex, 0), displayableAttachments.count - 1)
        return displayableAttachments[safeIndex]
    }

    private var selectedAttachmentAltTextForDisplay: String? {
        guard showAlternativeText else {
            return nil
        }

        return selectedAttachmentForMetadata?.description?.nilIfEmpty
    }

    private var statusCategoryName: String? {
        displayedStatus.category?.name?.nilIfEmpty
    }

    private var multiAttachmentHeight: CGFloat {
        attachmentHeight(for: selectedAttachmentForMetadata)
    }

    private var singleAttachmentHeight: CGFloat {
        attachmentHeight(for: displayableAttachments.first)
    }

    private var canDeleteStatus: Bool {
        if isStatusOwner {
            return true
        }

        let roles = appState.activeTokenRoles
        return roles.contains("administrator") || roles.contains("moderator")
    }

    private var canFeatureStatus: Bool {
        let roles = appState.activeTokenRoles
        return roles.contains("administrator") || roles.contains("moderator")
    }

    private var canApplyContentWarning: Bool {
        let roles = appState.activeTokenRoles
        return roles.contains("administrator") || roles.contains("moderator")
    }

    private var canReportStatus: Bool {
        displayedStatus.user?.id?.nilIfEmpty != nil
    }

    private var isStatusOwner: Bool {
        guard let activeUserName = appState.activeAccount?.userName.trimmingPrefix("@").lowercased().nilIfEmpty,
              let statusUserName = displayedStatus.user?.userName?.trimmingPrefix("@").lowercased().nilIfEmpty else {
            return false
        }

        return activeUserName == statusUserName
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Comments")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            Button {
                presentAddCommentSheet()
            } label: {
                Label("Add comment", systemImage: "plus.bubble")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)

            if isCommentsLoading && comments.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 6)
            } else if comments.isEmpty {
                Text("No comments yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 6)
            } else {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(comments) { item in
                        StatusDetailCommentRowView(
                            comment: item.status,
                            isIndented: item.isIndented,
                            onOpenMarkdownURL: handleStatusMarkdownURL,
                            onToggleFavourite: {
                                Task {
                                    await toggleFavourite(for: item.status)
                                }
                            },
                            onReply: {
                                presentReplySheet(for: item.status)
                            },
                            onTranslate: {
                                presentTranslation(for: item.status)
                            },
                            onCopyText: {
                                copyTextForStatus(item.status)
                            },
                            onReport: {
                                presentReportSheet(for: item.status)
                            }
                        )
                    }
                }
            }
        }
        .padding(14)
        .liquidGlassCard()
    }

    private var statusMoreMenu: some View {
        Menu {
            statusMoreMenuContent
        } label: {
            statusMoreMenuLabel
        }
    }

    @ViewBuilder
    private var statusMoreMenuContent: some View {
        statusMoreMenuEditSection
        statusMoreMenuAudienceSection
        statusMoreMenuLinksSection
        statusMoreMenuDeleteSection
    }

    @ViewBuilder
    private var statusMoreMenuEditSection: some View {
        if isStatusOwner {
            Button {
                statusForEditing = displayedStatus
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Divider()
        }
    }

    private var statusMoreMenuAudienceSection: some View {
        Group {
            Button {
                presentedUsersListKind = .boostedBy
            } label: {
                Label("Boosted by", systemImage: "arrow.2.squarepath")
            }

            Button {
                presentedUsersListKind = .favouritedBy
            } label: {
                Label("Favourited by", systemImage: "star")
            }

            Divider()
        }
    }

    @ViewBuilder
    private var statusMoreMenuLinksSection: some View {
        Button {
            copyLinkToStatus()
        } label: {
            Label("Copy link to post", systemImage: "link")
        }
        .disabled(displayedStatus.shareURL?.nilIfEmpty == nil)

        if let urlString = displayedStatus.shareURL?.nilIfEmpty, let url = URL(string: urlString) {
            Link(destination: url) {
                Label("Open in browser", systemImage: "safari")
            }

            ShareLink(item: url) {
                Label("Share status", systemImage: "square.and.arrow.up")
            }
        }

        Button {
            guard let plainText = prepareStatusTextForTranslation() else {
                return
            }

            translationSourceText = plainText
            isShowingTranslateSheet = true
        } label: {
            Label("Translate", systemImage: "translate")
        }
        .disabled(!canTranslateStatusText)

        Button {
            presentReportSheet(for: displayedStatus)
        } label: {
            Label("Report", systemImage: "flag")
        }
        .disabled(!canReportStatus)

        if canApplyContentWarning {
            Button {
                isShowingApplyContentWarningSheet = true
            } label: {
                Label("Apply CW", systemImage: "exclamationmark.triangle")
            }
        }
    }

    @ViewBuilder
    private var statusMoreMenuDeleteSection: some View {
        if canDeleteStatus {
            Divider()
            Button(role: .destructive) {
                showDeleteStatusConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var statusMoreMenuLabel: some View {
        Image(systemName: "ellipsis")
            .font(.title3)
    }

    private func replyComposerSheet(for target: ReplySheetTarget) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(target.headerText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextEditor(text: $replyText)
                    .focused($isReplyFieldFocused)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 140, maxHeight: 220)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.secondary.opacity(0.10))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(.secondary.opacity(0.22), lineWidth: 1)
                    )
                    .onChange(of: replyText) { _, newValue in
                        if newValue.count > maxCommentLength {
                            replyText = String(newValue.prefix(maxCommentLength))
                        }
                    }

                HStack {
                    Spacer(minLength: 0)
                    Text("\(replyText.count)/\(maxCommentLength)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .navigationTitle(target.sheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        cancelReplySheet()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await submitReplyComment() }
                    } label: {
                        if isSendingReply {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Send")
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(isSendingReply || !isMeaningfulComment(replyText, for: target.status))
                }
            }
            .onAppear {
                fillReplyMention(for: target.status, force: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isReplyFieldFocused = true
                }
            }
        }
    }

    private func attachmentHeight(for attachment: Attachment?) -> CGFloat {
        let contentWidth = mediaContentWidth > 0 ? mediaContentWidth : 360
        let ratio = attachment?.aspectRatio ?? 1
        let calculatedHeight = contentWidth / max(ratio, 0.2)
        return min(max(calculatedHeight, 220), 560)
    }

    private func updateMediaContentWidth(from paddedWidth: CGFloat) {
        let calculatedWidth = max(paddedWidth - 32, 1)
        guard abs(calculatedWidth - mediaContentWidth) > 0.5 else {
            return
        }

        mediaContentWidth = calculatedWidth
    }

    private var resolvedMediaContentWidth: CGFloat {
        mediaContentWidth > 0 ? mediaContentWidth : 360
    }

    private func copyLinkToStatus() {
        guard let link = displayedStatus.shareURL?.nilIfEmpty else {
            return
        }

        UIPasteboard.general.string = link
    }

    private var canTranslateStatusText: Bool {
        displayedStatus.noteForDisplay?.nilIfEmpty != nil
    }

    private func prepareStatusTextForTranslation() -> String? {
        statusPlainText(from: displayedStatus)
    }

    private func statusPlainText(from status: Status) -> String? {
        guard let note = status.noteForDisplay?.nilIfEmpty else {
            return nil
        }

        let plainText = note.decodingHTMLEntities
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return plainText.nilIfEmpty
    }

    private func presentTranslation(for status: Status) {
        guard let plainText = statusPlainText(from: status) else {
            return
        }

        translationSourceText = plainText
        isShowingTranslateSheet = true
    }

    private func copyTextForStatus(_ status: Status) {
        guard let plainText = statusPlainText(from: status) else {
            return
        }

        UIPasteboard.general.string = plainText
    }

    private func openAttachmentViewer(at index: Int) {
        guard !displayableAttachments.isEmpty else {
            return
        }

        attachmentViewerInitialIndex = min(max(index, 0), displayableAttachments.count - 1)
        isAttachmentViewerPresented = true
    }

    @ViewBuilder
    private func statusAttachmentView(for attachment: Attachment, fixedHeight: CGFloat) -> some View {
        if let imageURL = attachment.smallImageURL {
            AsyncImage(url: URL(string: imageURL),
                       transaction: Transaction(animation: .easeInOut(duration: 0.3))) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .transition(.opacity)
                        .frame(width: resolvedMediaContentWidth, height: fixedHeight)
                case .empty, .failure:
                    AttachmentBlurHashPlaceholderView(blurHash: attachment.blurhash,
                                                  cornerRadius: 20,
                                                  aspectRatio: nil,
                                                  fixedHeight: nil)
                        .frame(width: resolvedMediaContentWidth, height: fixedHeight)
                @unknown default:
                    AttachmentBlurHashPlaceholderView(blurHash: attachment.blurhash,
                                                  cornerRadius: 20,
                                                  aspectRatio: nil,
                                                  fixedHeight: nil)
                        .frame(width: resolvedMediaContentWidth, height: fixedHeight)
                }
            }
            .frame(maxWidth: .infinity)
        } else {
            AttachmentBlurHashPlaceholderView(blurHash: attachment.blurhash,
                                          cornerRadius: 20,
                                          aspectRatio: nil,
                                          fixedHeight: nil)
                .frame(width: resolvedMediaContentWidth, height: fixedHeight)
                .frame(maxWidth: .infinity)
        }
    }

    @MainActor
    private func toggleReblog() async {
        isBoostProcessing = true
        defer { isBoostProcessing = false }

        let action: StatusInteractionAction = displayedStatus.reblogged == true ? .unreblog : .reblog
        await performAction(action)
    }

    @MainActor
    private func toggleFavourite() async {
        isFavouriteProcessing = true
        defer { isFavouriteProcessing = false }

        let action: StatusInteractionAction = displayedStatus.favourited == true ? .unfavourite : .favourite
        await performAction(action)
    }

    @MainActor
    private func toggleFavourite(for status: Status) async {
        let action: StatusInteractionAction = status.favourited == true ? .unfavourite : .favourite

        do {
            let updatedStatus = try await appState.updateStatusInteraction(statusId: status.id, action: action)
            if let index = comments.firstIndex(where: { $0.status.id == status.id }) {
                comments[index] = StatusCommentItem(status: updatedStatus, isIndented: comments[index].isIndented)
            }
            actionErrorMessage = nil
        } catch {
            actionErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    @MainActor
    private func toggleBookmark() async {
        isBookmarkProcessing = true
        defer { isBookmarkProcessing = false }

        let action: StatusInteractionAction = displayedStatus.bookmarked == true ? .unbookmark : .bookmark
        await performAction(action)
    }

    @MainActor
    private func toggleFeature() async {
        isFeatureProcessing = true
        defer { isFeatureProcessing = false }

        let action: StatusInteractionAction = displayedStatus.featured == true ? .unfeature : .feature
        await performAction(action)
    }

    @MainActor
    private func performAction(_ action: StatusInteractionAction) async {
        do {
            displayedStatus = try await appState.updateStatusInteraction(statusId: displayedStatus.id, action: action)
            actionErrorMessage = nil
        } catch {
            actionErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    @MainActor
    private func loadStatusDetail() async {
        await refreshStatusFromServer()
        await loadComments()
    }

    @MainActor
    private func refreshStatusFromServer() async {
        do {
            displayedStatus = try await appState.fetchStatus(statusId: displayedStatus.id)
        } catch {
            // Keep current snapshot when refresh fails.
        }
    }

    @MainActor
    private func deleteDisplayedStatus() async {
        guard canDeleteStatus else {
            return
        }

        do {
            try await appState.deleteStatus(statusId: displayedStatus.id)
            dismiss()
        } catch {
            actionErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    @MainActor
    private func loadComments() async {
        isCommentsLoading = true
        defer { isCommentsLoading = false }

        do {
            let context = try await appState.fetchStatusContext(statusId: displayedStatus.id)
            comments = flattenComments(rootStatusId: displayedStatus.id, descendants: context.descendants)
            commentsErrorMessage = nil
        } catch {
            commentsErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    @MainActor
    private func presentAddCommentSheet() {
        let target = ReplySheetTarget(status: displayedStatus, mode: .comment)
        replySheetTarget = target
        fillReplyMention(for: target.status, force: true)
    }

    @MainActor
    private func presentReplySheet(for status: Status) {
        let target = ReplySheetTarget(status: status, mode: .reply)
        replySheetTarget = target
        fillReplyMention(for: target.status, force: true)
    }

    @MainActor
    private func presentReportSheet(for status: Status) {
        reportSheetStatus = status.mainStatus
    }

    @MainActor
    private func cancelReplySheet() {
        replySheetTarget = nil
        replyText = ""
    }

    @MainActor
    private func submitReplyComment() async {
        guard let target = replySheetTarget?.status else {
            return
        }

        let note = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isMeaningfulComment(note, for: target) else {
            return
        }

        isSendingReply = true
        defer { isSendingReply = false }

        do {
            _ = try await appState.createComment(note: note, replyToStatusId: target.id)
            await refreshStatusFromServer()
            await loadComments()
            cancelReplySheet()
            actionErrorMessage = nil
        } catch {
            actionErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func fillReplyMention(for status: Status, force: Bool) {
        guard force || replyText.nilIfEmpty == nil else {
            return
        }

        replyText = mentionPrefix(for: status)
    }

    private func mentionPrefix(for status: Status) -> String {
        if let userName = status.user?.userName?.trimmingPrefix("@").nilIfEmpty {
            return "@\(userName) "
        }

        return ""
    }

    private func isMeaningfulComment(_ text: String, for target: Status) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }

        guard let targetUserName = target.user?.userName?.trimmingPrefix("@").nilIfEmpty else {
            return true
        }

        let mention = "@\(targetUserName)"
        if let mentionRange = trimmed.range(of: mention, options: [.anchored, .caseInsensitive]) {
            let remainder = trimmed[mentionRange.upperBound...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return !remainder.isEmpty
        }

        return true
    }

    private func flattenComments(rootStatusId: String, descendants: [Status]) -> [StatusCommentItem] {
        var flattened: [StatusCommentItem] = []
        let directReplies = descendants.filter { $0.replyToStatusId == rootStatusId }

        for reply in directReplies {
            flattened.append(StatusCommentItem(status: reply, isIndented: false))
            appendNestedReplies(from: descendants, parentStatusId: reply.id, to: &flattened)
        }

        return flattened
    }

    private func appendNestedReplies(from descendants: [Status], parentStatusId: String, to output: inout [StatusCommentItem]) {
        let nestedReplies = descendants.filter { $0.replyToStatusId == parentStatusId }
        for reply in nestedReplies {
            output.append(StatusCommentItem(status: reply, isIndented: true))
            appendNestedReplies(from: descendants, parentStatusId: reply.id, to: &output)
        }
    }

    private var statusAuthorHeader: some View {
        HStack(spacing: 10) {
            AsyncAvatarView(urlString: displayedStatus.user?.avatarUrl)

            VStack(alignment: .leading, spacing: 2) {
                Text(displayedStatus.user?.name?.nilIfEmpty ?? displayedStatus.user?.userName ?? "Unknown")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("@\(displayedStatus.user?.userName ?? "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func handleStatusMarkdownURL(_ url: URL) -> OpenURLAction.Result {
        if let hashtag = hashtagName(from: url) {
            hashtagTimelineRoute = HashtagTimelineRoute(hashtagName: hashtag)
            return .handled
        }

        if let userName = userName(from: url) {
            openMentionedUserOrFallback(userName: userName, fallbackURL: url)
            return .handled
        }

        return .systemAction
    }

    private func openMentionedUserOrFallback(userName: String, fallbackURL: URL) {
        Task {
            do {
                let result = try await appState.search(query: userName, type: SearchScopeSelection.users.rawValue)
                if let matchedUser = preferredMentionSearchUser(in: result.users ?? [], query: userName),
                   let routeUserName = routeUserName(from: matchedUser) {
                    mentionedUserRoute = MentionedUserRoute(
                        userName: routeUserName,
                        preferredDisplayName: matchedUser.name?.nilIfEmpty
                    )
                    return
                }
            } catch {
                // If account search fails, fallback to opening URL in browser.
            }

            openURL(fallbackURL)
        }
    }

    private func hashtagName(from url: URL) -> String? {
        if let fragment = url.fragment?.nilIfEmpty {
            let normalizedFragment = fragment.trimmingPrefix("#")
            if !normalizedFragment.isEmpty {
                return normalizedFragment
            }
        }

        let pathComponents = url.pathComponents
        if pathComponents.contains(where: { $0.caseInsensitiveCompare("tags") == .orderedSame }),
           let lastComponent = pathComponents.last?.nilIfEmpty {
            let normalizedTag = lastComponent.trimmingPrefix("#")
            return normalizedTag.nilIfEmpty
        }

        return nil
    }

    private func userName(from url: URL) -> String? {
        userNameFromAtPath(url)
    }

    private func userNameFromAtPath(_ url: URL) -> String? {
        guard let lastPathComponent = url.lastPathComponent.nilIfEmpty,
              lastPathComponent.first == "@",
              let host = url.host?.nilIfEmpty else {
            return nil
        }

        let userPart = lastPathComponent
            .trimmingPrefix("@")
            .split(separator: "@", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map(String.init)

        guard let normalizedUserPart = userPart?.nilIfEmpty else {
            return nil
        }

        return "\(normalizedUserPart)@\(host)"
    }

    private func preferredMentionSearchUser(in users: [User], query: String) -> User? {
        let normalizedQuery = query.trimmingPrefix("@").lowercased()
        guard !users.isEmpty else {
            return nil
        }

        if let exactMatch = users.first(where: { user in
            let userName = user.userName?.trimmingPrefix("@").lowercased()
            let account = user.account?.trimmingPrefix("@").lowercased()
            return userName == normalizedQuery || account == normalizedQuery
        }) {
            return exactMatch
        }

        return users.first
    }

    private func routeUserName(from user: User) -> String? {
        if let userName = user.userName?.trimmingPrefix("@").nilIfEmpty {
            return userName
        }

        if let account = user.account?.trimmingPrefix("@").nilIfEmpty {
            return account
        }

        return nil
    }
}
