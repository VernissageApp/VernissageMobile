//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI
import PhotosUI

struct StatusComposeScreen: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppStorageKeys.composeSelectedCategoryId) private var rememberedSelectedCategoryId = ""

    let mode: StatusComposeMode
    let initialAttachmentURLs: [URL]
    let onDismissRequested: (() -> Void)?
    var onStatusSaved: ((Status) -> Void)? = nil

    private static let statusTextTemplateKey = "status-text-template"
    private let maxAttachmentLongestEdge: CGFloat = 4096

    @State private var profile: User?
    @State private var statusText: String
    @State private var selectedVisibility: StatusVisibility
    @State private var commentsDisabled: Bool
    @State private var isSensitive: Bool
    @State private var contentWarning: String
    @State private var selectedCategoryId: String?
    @State private var attachments: [ComposeStatusAttachment]

    @State private var categories: [Category] = []
    @State private var licenses: [License] = []
    @State private var countries: [Country] = []
    @State private var maxStatusCharacters: Int = 500
    @State private var maxMediaAttachments: Int = 4
    @State private var maxAttachmentImageSizeLimitBytes: Int?
    @State private var isOpenAIEnabled = false
    @State private var statusTextTemplate = ""

    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isPhotoPickerPresented = false
    @State private var isCameraPickerPresented = false
    @State private var isFileImporterPresented = false
    @State private var selectedAttachmentSheet: ComposeAttachmentSheetSelection?
    @State private var isEditingTemplate = false

    @State private var mentionSuggestions: [User] = []
    @State private var hashtagSuggestions: [Hashtag] = []
    @State private var autocompleteMode: ComposeAutocompleteMode?
    @State private var autocompleteTask: Task<Void, Never>?

    @State private var isLoadingInitialData = false
    @State private var didLoadInitialData = false
    @State private var importedInitialAttachmentURLKeys: Set<String> = []
    @State private var isPublishing = false
    @State private var errorMessage: String?
    @FocusState private var isTextFocused: Bool

    init(
        mode: StatusComposeMode,
        initialAttachmentURLs: [URL] = [],
        onDismissRequested: (() -> Void)? = nil,
        onStatusSaved: ((Status) -> Void)? = nil
    ) {
        self.mode = mode
        self.initialAttachmentURLs = initialAttachmentURLs
        self.onDismissRequested = onDismissRequested
        self.onStatusSaved = onStatusSaved

        if let status = mode.editingStatus {
            _statusText = State(initialValue: status.note?.nilIfEmpty ?? "")
            _selectedVisibility = State(initialValue: StatusVisibility(rawValue: status.visibility ?? "") ?? .public)
            _commentsDisabled = State(initialValue: status.commentsDisabled ?? false)
            _isSensitive = State(initialValue: status.sensitive ?? false)
            _contentWarning = State(initialValue: status.contentWarning?.nilIfEmpty ?? "")
            _selectedCategoryId = State(initialValue: status.category?.id?.nilIfEmpty)
            _attachments = State(initialValue: (status.attachments ?? []).map { ComposeStatusAttachment.existing($0) })
        } else {
            _statusText = State(initialValue: "")
            _selectedVisibility = State(initialValue: .public)
            _commentsDisabled = State(initialValue: false)
            _isSensitive = State(initialValue: false)
            _contentWarning = State(initialValue: "")
            _selectedCategoryId = State(initialValue: nil)
            _attachments = State(initialValue: [])
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let composeAccountIdentity {
                        composeAccountIdentitySection(composeAccountIdentity)
                    }

                    if commentsDisabled {
                        Text("COMMENTS WILL BE DISABLED")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.red)
                    }

                    if isSensitive {
                        TextField("Content warning", text: $contentWarning, axis: .vertical)
                            .lineLimit(1...3)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(.red.opacity(0.12))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(.red.opacity(0.35), lineWidth: 1)
                            )
                    }
                    
                    attachmentsSection
                    textSection
                    visibilitySection
                }
                .padding(16)
                .padding(.bottom, 20)
            }
            .navigationTitle(mode.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        Task { await cancelCompose() }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await publishStatus() }
                    } label: {
                        if isPublishing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text(mode.publishTitle)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!canPublish)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    if hasAutocompleteSuggestions {
                        autocompleteSuggestionsBar
                            .padding(.vertical, 6)
                    }

                    composerToolbar
                }
                .background(.ultraThinMaterial)
            }
        }
        .onFirstAppear {
            await loadInitialDataIfNeeded()
            await importInitialAttachmentURLsIfNeeded(initialAttachmentURLs)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isTextFocused = true
            }
        }
        .onDisappear {
            autocompleteTask?.cancel()
        }
        .onChange(of: statusText, initial: false) { _, newValue in
            if newValue.count > maxStatusCharacters {
                statusText = String(newValue.prefix(maxStatusCharacters))
            }

            scheduleAutocomplete()
        }
        .onChange(of: selectedPhotoItems, initial: false) { _, newItems in
            Task {
                await handleSelectedPhotos(newItems)
                selectedPhotoItems = []
            }
        }
        .onChange(of: initialAttachmentURLs, initial: false) { _, newURLs in
            Task {
                await importInitialAttachmentURLsIfNeeded(newURLs)
            }
        }
        .onChange(of: selectedCategoryId, initial: false) { _, newValue in
            rememberedSelectedCategoryId = newValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        .onChange(of: isSensitive, initial: false) { _, newValue in
            if !newValue {
                contentWarning = ""
            }
        }
        .photosPicker(
            isPresented: $isPhotoPickerPresented,
            selection: $selectedPhotoItems,
            maxSelectionCount: max(1, min(remainingAttachmentSlots, maxMediaAttachments)),
            matching: .images
        )
        .fullScreenCover(isPresented: $isCameraPickerPresented) {
            ComposeCameraPickerView { image in
                Task {
                    await handleCameraImage(image)
                }
            }
            .ignoresSafeArea()
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.image],
            allowsMultipleSelection: remainingAttachmentSlots > 1
        ) { result in
            Task {
                await handleSelectedFileImportResult(result)
            }
        }
        .sheet(item: $selectedAttachmentSheet) { sheet in
            if let attachmentBinding = bindingForAttachment(id: sheet.id) {
                ComposeAttachmentDetailsSheet(
                    attachment: attachmentBinding,
                    licenses: licenses,
                    countries: countries,
                    isOpenAIEnabled: isOpenAIEnabled
                ) { countryCode, query in
                    try await appState.searchLocations(countryCode: countryCode, query: query)
                } generateDescription: { attachmentId in
                    try await appState.describeAttachment(attachmentId: attachmentId)
                }
            } else {
                EmptyView()
            }
        }
        .sheet(isPresented: $isEditingTemplate) {
            StatusTextTemplateSheet(template: statusTextTemplate) { templateValue in
                let sanitizedValue = String(templateValue.prefix(1000))
                _ = try await appState.setUserSetting(
                    key: Self.statusTextTemplateKey,
                    value: sanitizedValue
                )
                await MainActor.run {
                    statusTextTemplate = sanitizedValue
                }
            }
            .presentationDetents([.medium])
        }
        .errorAlertToast($errorMessage)
    }

    private struct ComposeAccountIdentity {
        let displayName: String
        let userNameLabel: String
        let avatarURL: String?
    }

    private var composeAccountIdentity: ComposeAccountIdentity? {
        let normalizedUserName = profile?.userName?.trimmingPrefix("@").nilIfEmpty
            ?? appState.activeAccount?.userName.trimmingPrefix("@").nilIfEmpty
        let displayName = profile?.name?.nilIfEmpty
            ?? appState.activeAccount?.displayName?.nilIfEmpty
            ?? normalizedUserName

        guard let displayName = displayName?.nilIfEmpty else {
            return nil
        }

        let userNameLabel = normalizedUserName.map { "@\($0)" } ?? "Signed account"
        let avatarURL = profile?.avatarUrl?.nilIfEmpty ?? appState.activeAccount?.avatarURL?.nilIfEmpty

        return ComposeAccountIdentity(
            displayName: displayName,
            userNameLabel: userNameLabel,
            avatarURL: avatarURL
        )
    }

    private func composeAccountIdentitySection(_ identity: ComposeAccountIdentity) -> some View {
        HStack(spacing: 10) {
            AsyncAvatarView(urlString: identity.avatarURL, size: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(identity.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(identity.userNameLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var visibilitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !categories.isEmpty {
                composeMenuField(title: "Category", value: selectedCategoryName) {
                    Button {
                        selectedCategoryId = nil
                    } label: {
                        if selectedCategoryId == nil {
                            Label("Without category", systemImage: "checkmark")
                        } else {
                            Text("Without category")
                        }
                    }

                    Divider()

                    ForEach(categories, id: \.id) { category in
                        Button {
                            selectedCategoryId = category.id
                        } label: {
                            if selectedCategoryId == category.id {
                                Label(category.name, systemImage: "checkmark")
                            } else {
                                Text(category.name)
                            }
                        }
                    }
                }
            }
            
            composeMenuField(title: "Visibility", value: selectedVisibility.title) {
                ForEach(StatusVisibility.allCases, id: \.rawValue) { item in
                    Button {
                        selectedVisibility = item
                    } label: {
                        if selectedVisibility == item {
                            Label(item.title, systemImage: "checkmark")
                        } else {
                            Text(item.title)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func composeMenuField<MenuContent: View>(
        title: String,
        value: String,
        @ViewBuilder menuContent: () -> MenuContent
    ) -> some View {
        Menu {
            menuContent()
        } label: {
            HStack(spacing: 10) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer(minLength: 10)

                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.secondary.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.secondary.opacity(0.24), lineWidth: 1)
            )
        }
    }

    private var textSection: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $statusText)
                .focused($isTextFocused)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 40)

            if statusText.isEmpty {
                Text("Attach a photo and type what's on your mind")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
        }
    }

    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(attachments) { attachment in
                        ComposeAttachmentThumbnailView(
                            attachment: attachment,
                            onTap: {
                                selectedAttachmentSheet = ComposeAttachmentSheetSelection(id: attachment.id)
                            },
                            onDelete: {
                                Task {
                                    await removeAttachment(attachment.id)
                                }
                            }
                        )
                    }

                    if remainingAttachmentSlots > 0 {
                        Menu {
                            photoSourceMenuContent()
                        } label: {
                            emptyAttachmentPlaceholderTile
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var emptyAttachmentPlaceholderTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.secondary.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        .foregroundStyle(.secondary.opacity(0.35))
                )

            VStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text("Add photo")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 102, height: 102)
    }

    private var composerToolbar: some View {
        HStack(spacing: 14) {
            Menu {
                photoSourceMenuContent()
            } label: {
                Image(systemName: "photo.on.rectangle")
            }
            .disabled(remainingAttachmentSlots <= 0)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSensitive.toggle()
                }
            } label: {
                Image(systemName: isSensitive ? "exclamationmark.square.fill" : "exclamationmark.square")
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    commentsDisabled.toggle()
                }
            } label: {
                Image(systemName: commentsDisabled ? "person.2.slash.fill" : "person.2.fill")
            }

            Button {
                insertComposerToken("#")
            } label: {
                Image(systemName: "number")
            }

            Button {
                insertComposerToken("@")
            } label: {
                Image(systemName: "at")
            }

            Button {
                insertStatusTemplate()
            } label: {
                Image(systemName: "text.badge.plus")
            }

            Button {
                isEditingTemplate = true
            } label: {
                Image(systemName: "pencil")
            }

            Spacer(minLength: 0)

            Text("\(remainingCharacters)")
                .font(.system(size: 18, weight: .regular, design: .rounded))
                .foregroundStyle(remainingCharacters < 0 ? .red : .secondary)
        }
        .font(.system(size: 22))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func photoSourceMenuContent() -> some View {
        Button {
            guard remainingAttachmentSlots > 0 else { return }
            isPhotoPickerPresented = true
        } label: {
            Label("Photos library", systemImage: "photo")
        }

        Button {
            guard remainingAttachmentSlots > 0 else { return }
            isCameraPickerPresented = true
        } label: {
            Label("Take photo", systemImage: "camera")
        }

        Button {
            guard remainingAttachmentSlots > 0 else { return }
            isFileImporterPresented = true
        } label: {
            Label("Browse files", systemImage: "folder")
        }
    }

    private var autocompleteSuggestionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                if autocompleteMode == .users {
                    ForEach(Array(mentionSuggestions.enumerated()), id: \.offset) { index, user in
                        Button {
                            applyMentionSuggestion(user)
                        } label: {
                            HStack(spacing: 8) {
                                AsyncAvatarView(urlString: user.avatarUrl, size: 34)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(user.name?.nilIfEmpty ?? user.userName ?? "Unknown")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Text("@\((user.userName ?? "").trimmingPrefix("@"))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.horizontal, 10)
                        }
                        .buttonStyle(.plain)

                        if index < mentionSuggestions.count - 1 {
                            Divider()
                                .frame(height: 32)
                        }
                    }
                } else {
                    ForEach(Array(hashtagSuggestions.enumerated()), id: \.offset) { index, hashtag in
                        Button {
                            applyHashtagSuggestion(hashtag)
                        } label: {
                            Text("#\(hashtag.name)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 12)
                        }
                        .buttonStyle(.plain)

                        if index < hashtagSuggestions.count - 1 {
                            Divider()
                                .frame(height: 24)
                        }
                    }
                }
            }
            .padding(.horizontal, 6)
        }
        .frame(height: 44)
    }

    private var hasAutocompleteSuggestions: Bool {
        !mentionSuggestions.isEmpty || !hashtagSuggestions.isEmpty
    }

    private var remainingAttachmentSlots: Int {
        max(maxMediaAttachments - attachments.count, 0)
    }

    private var remainingCharacters: Int {
        maxStatusCharacters - statusText.count
    }

    private var selectedCategoryName: String {
        if let selectedCategoryId,
           let selectedCategory = categories.first(where: { $0.id == selectedCategoryId }) {
            return selectedCategory.name
        }

        return "Without category"
    }

    private var canPublish: Bool {
        if isPublishing || isLoadingInitialData {
            return false
        }

        if statusText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }

        if attachments.isEmpty {
            return false
        }

        if attachments.contains(where: { $0.isUploading }) {
            return false
        }

        if remainingCharacters < 0 {
            return false
        }

        return true
    }

    private var editingStatusId: String? {
        mode.editingStatus?.id
    }

    @MainActor
    private func loadInitialDataIfNeeded() async {
        guard !didLoadInitialData else {
            return
        }

        didLoadInitialData = true
        isLoadingInitialData = true
        defer { isLoadingInitialData = false }

        do {
            async let fetchedProfile = appState.fetchActiveProfile()
            async let fetchedCategories = appState.fetchCategories()
            async let fetchedLicenses = appState.fetchLicenses()
            async let fetchedCountries = appState.fetchCountries()
            async let fetchedInstance = appState.fetchInstanceDetails()
            async let fetchedPublicSettings = appState.fetchPublicSettings()
            async let fetchedStatusTextTemplate = appState.fetchUserSetting(key: Self.statusTextTemplateKey)

            profile = try await fetchedProfile
            categories = try await fetchedCategories.sorted { $0.priority ?? 0 < $1.priority ?? 0 }
            licenses = try await fetchedLicenses.sorted { ($0.name ?? "") < ($1.name ?? "") }
            countries = try await fetchedCountries.sorted { ($0.name ?? "") < ($1.name ?? "") }
            applyRememberedCategoryIfNeeded()

            let instance = try await fetchedInstance
            maxStatusCharacters = max(instance.configuration?.statuses?.maxCharacters ?? 500, 1)
            maxMediaAttachments = max(instance.configuration?.statuses?.maxMediaAttachments ?? 4, 1)
            if let imageSizeLimit = instance.configuration?.attachments?.imageSizeLimit,
               imageSizeLimit > 0 {
                maxAttachmentImageSizeLimitBytes = imageSizeLimit
            } else {
                maxAttachmentImageSizeLimitBytes = nil
            }
            isOpenAIEnabled = (try? await fetchedPublicSettings)?.isOpenAIEnabled ?? false
            statusTextTemplate = (try? await fetchedStatusTextTemplate)?.value ?? ""

            if let editingStatusId {
                do {
                    let refreshedStatus = try await appState.fetchStatus(statusId: editingStatusId)
                    applyEditingSnapshot(from: refreshedStatus)
                } catch {
                    // Keep already prefilled status values when refresh fails.
                }
            }

            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    @MainActor
    private func applyEditingSnapshot(from status: Status) {
        statusText = status.note?.nilIfEmpty ?? statusText
        selectedVisibility = StatusVisibility(rawValue: status.visibility ?? "") ?? selectedVisibility
        commentsDisabled = status.commentsDisabled ?? commentsDisabled
        isSensitive = status.sensitive ?? isSensitive
        contentWarning = status.contentWarning?.nilIfEmpty ?? contentWarning
        selectedCategoryId = status.category?.id?.nilIfEmpty ?? selectedCategoryId
        attachments = (status.attachments ?? []).map { ComposeStatusAttachment.existing($0) }
    }

    @MainActor
    private func applyRememberedCategoryIfNeeded() {
        guard mode.editingStatus == nil else {
            return
        }

        guard selectedCategoryId?.nilIfEmpty == nil else {
            return
        }

        guard let rememberedCategoryId = rememberedSelectedCategoryId.nilIfEmpty else {
            return
        }

        guard categories.contains(where: { $0.id == rememberedCategoryId }) else {
            rememberedSelectedCategoryId = ""
            return
        }

        selectedCategoryId = rememberedCategoryId
    }

    @MainActor
    private func handleSelectedPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else {
            return
        }

        var freeSlots = remainingAttachmentSlots
        guard freeSlots > 0 else {
            errorMessage = "Maximum number of media attachments reached."
            return
        }

        for item in items {
            guard freeSlots > 0 else {
                break
            }

            do {
                guard let originalData = try await item.loadTransferable(type: Data.self),
                      let prepared = preparedAttachmentPayload(from: originalData) else {
                    continue
                }

                guard validatePreparedAttachmentSizeLimit(prepared.data) else {
                    continue
                }

                let parsedExif = ComposeParsedExifParser.parse(from: originalData)
                let localAttachment = ComposeStatusAttachment.local(
                    image: prepared.image,
                    imageData: prepared.data,
                    parsedExif: parsedExif
                )
                let attachmentId = localAttachment.id
                attachments.append(localAttachment)

                freeSlots -= 1
                try await uploadAttachmentIfNeeded(attachmentId: attachmentId)
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    @MainActor
    private func handleCameraImage(_ image: UIImage?) async {
        guard let image else {
            return
        }

        guard remainingAttachmentSlots > 0 else {
            errorMessage = "Maximum number of media attachments reached."
            return
        }

        guard let prepared = preparedAttachmentPayload(from: image) else {
            errorMessage = "Unable to prepare selected photo."
            return
        }

        guard validatePreparedAttachmentSizeLimit(prepared.data) else {
            return
        }

        let attachment = ComposeStatusAttachment.local(
            image: prepared.image,
            imageData: prepared.data,
            parsedExif: .init()
        )
        let attachmentId = attachment.id
        attachments.append(attachment)

        do {
            try await uploadAttachmentIfNeeded(attachmentId: attachmentId)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    @MainActor
    private func handleSelectedFileImportResult(_ result: Result<[URL], any Error>) async {
        switch result {
        case .success(let urls):
            await handleSelectedFileURLs(urls)
        case .failure(let error):
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    @MainActor
    private func handleSelectedFileURLs(_ urls: [URL], removeImportedFilesAtSource: Bool = false) async {
        guard !urls.isEmpty else {
            return
        }

        var freeSlots = remainingAttachmentSlots
        guard freeSlots > 0 else {
            errorMessage = "Maximum number of media attachments reached."
            return
        }

        for url in urls {
            guard freeSlots > 0 else {
                break
            }

            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            defer {
                if removeImportedFilesAtSource {
                    try? FileManager.default.removeItem(at: url)
                }
            }

            do {
                guard let prepared = autoreleasepool(invoking: { preparedAttachmentPayload(fromFileURL: url) }) else {
                    continue
                }

                guard validatePreparedAttachmentSizeLimit(prepared.data) else {
                    continue
                }

                let parsedExif = autoreleasepool(invoking: { ComposeParsedExifParser.parse(from: url) })
                let localAttachment = ComposeStatusAttachment.local(
                    image: prepared.image,
                    imageData: prepared.data,
                    parsedExif: parsedExif
                )
                let attachmentId = localAttachment.id
                attachments.append(localAttachment)

                freeSlots -= 1
                try await uploadAttachmentIfNeeded(attachmentId: attachmentId)
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    @MainActor
    private func importInitialAttachmentURLsIfNeeded(_ urls: [URL]) async {
        guard mode.editingStatus == nil else {
            return
        }

        let urlsToImport = urls.filter { url in
            importedInitialAttachmentURLKeys.insert(urlImportKey(for: url)).inserted
        }

        guard urlsToImport.isEmpty == false else {
            return
        }

        await handleSelectedFileURLs(urlsToImport, removeImportedFilesAtSource: true)
    }

    private func urlImportKey(for url: URL) -> String {
        url.standardizedFileURL.absoluteString
    }

    @MainActor
    private func uploadAttachmentIfNeeded(attachmentId: UUID) async throws {
        guard let index = attachments.firstIndex(where: { $0.id == attachmentId }) else {
            return
        }

        guard attachments[index].serverId?.nilIfEmpty == nil else {
            return
        }

        guard let uploadData = attachments[index].resizedImageData,
              uploadData.isEmpty == false else {
            throw ComposeError.uploadPreparationFailed
        }

        attachments[index].isUploading = true
        attachments[index].uploadErrorMessage = nil
        defer {
            if let safeIndex = attachments.firstIndex(where: { $0.id == attachmentId }) {
                attachments[safeIndex].isUploading = false
            }
        }

        do {
            let uploaded = try await appState.uploadAttachment(
                imageData: uploadData,
                fileName: "photo-\(UUID().uuidString.prefix(8)).jpg",
                mimeType: "image/jpeg"
            )

            if let safeIndex = attachments.firstIndex(where: { $0.id == attachmentId }) {
                attachments[safeIndex].serverId = uploaded.id
                attachments[safeIndex].remoteImageURL = uploaded.previewUrl?.nilIfEmpty ?? uploaded.url?.nilIfEmpty
                attachments[safeIndex].blurhash = uploaded.blurhash?.nilIfEmpty ?? attachments[safeIndex].blurhash
            }
        } catch {
            if let safeIndex = attachments.firstIndex(where: { $0.id == attachmentId }) {
                attachments[safeIndex].uploadErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            throw error
        }
    }

    @MainActor
    private func removeAttachment(_ attachmentId: UUID) async {
        guard let index = attachments.firstIndex(where: { $0.id == attachmentId }) else {
            return
        }

        let item = attachments[index]
        attachments.remove(at: index)

        if !item.isExistingAttachment,
           let serverId = item.serverId?.nilIfEmpty {
            do {
                try await appState.deleteAttachment(attachmentId: serverId)
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    @MainActor
    private func cancelCompose() async {
        await cleanupTemporaryAttachments()
        if let onDismissRequested {
            onDismissRequested()
        } else {
            dismiss()
        }
    }

    @MainActor
    private func cleanupTemporaryAttachments() async {
        let temporaryAttachmentIds = attachments
            .filter { !$0.isExistingAttachment }
            .compactMap { $0.serverId?.nilIfEmpty }

        for attachmentId in temporaryAttachmentIds {
            try? await appState.deleteAttachment(attachmentId: attachmentId)
        }
    }

    @MainActor
    private func publishStatus() async {
        guard canPublish else {
            return
        }

        isPublishing = true
        defer { isPublishing = false }

        do {
            for attachment in attachments where attachment.serverId?.nilIfEmpty == nil {
                try await uploadAttachmentIfNeeded(attachmentId: attachment.id)
            }

            let serverAttachmentIds = attachments.compactMap { $0.serverId?.nilIfEmpty }
            guard !serverAttachmentIds.isEmpty else {
                throw ComposeError.missingUploadedAttachments
            }

            for index in attachments.indices {
                if attachments[index].blurhash?.nilIfEmpty == nil,
                   let localImage = attachments[index].localImage {
                    attachments[index].blurhash = localImage.blurHash(numberOfComponents: (4, 3), maxLongestEdge: 180)
                }

                guard let serverId = attachments[index].serverId?.nilIfEmpty,
                      let payload = attachments[index].attachmentUpdateRequest() else {
                    continue
                }

                try await appState.updateAttachment(attachmentId: serverId, request: payload)
            }

            let payload = StatusComposeRequest(
                id: editingStatusId,
                note: statusText.trimmingCharacters(in: .whitespacesAndNewlines),
                visibility: selectedVisibility.rawValue,
                sensitive: isSensitive,
                contentWarning: isSensitive ? contentWarning.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty : nil,
                commentsDisabled: commentsDisabled,
                replyToStatusId: nil,
                attachmentIds: serverAttachmentIds,
                categoryId: selectedCategoryId?.nilIfEmpty
            )

            let savedStatus: Status
            if let editingStatusId {
                savedStatus = try await appState.updateStatus(statusId: editingStatusId, request: payload)
            } else {
                savedStatus = try await appState.createStatus(request: payload)
            }

            onStatusSaved?(savedStatus)
            errorMessage = nil
            if let onDismissRequested {
                onDismissRequested()
            } else {
                dismiss()
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func insertComposerToken(_ token: String) {
        let needsSpace = !statusText.isEmpty && !statusText.hasSuffix(" ")
        statusText += (needsSpace ? " " : "") + token
        isTextFocused = true
        scheduleAutocomplete()
    }

    private func insertStatusTemplate() {
        let template = statusTextTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !template.isEmpty else {
            errorMessage = "Before using template, define it first in Edit template."
            return
        }

        statusText += statusTextTemplate
        isTextFocused = true
        scheduleAutocomplete()
    }

    private func scheduleAutocomplete() {
        autocompleteTask?.cancel()

        guard let token = currentAutocompleteToken() else {
            autocompleteMode = nil
            mentionSuggestions = []
            hashtagSuggestions = []
            return
        }

        autocompleteTask = Task {
            try? await Task.sleep(nanoseconds: 260_000_000)
            guard !Task.isCancelled else {
                return
            }

            await fetchAutocompleteSuggestions(for: token)
        }
    }

    private func currentAutocompleteToken() -> String? {
        guard let range = statusText.range(of: "([#@][A-Za-z0-9_\\.-]*)$", options: .regularExpression) else {
            return nil
        }

        let token = String(statusText[range])
        return token.count >= 2 ? token : nil
    }

    @MainActor
    private func fetchAutocompleteSuggestions(for token: String) async {
        guard let marker = token.first else {
            return
        }

        let query = String(token.dropFirst())
        guard !query.isEmpty else {
            autocompleteMode = nil
            mentionSuggestions = []
            hashtagSuggestions = []
            return
        }

        do {
            switch marker {
            case "@":
                let result = try await appState.search(query: query, type: "users")
                mentionSuggestions = Array((result.users ?? []).prefix(12))
                hashtagSuggestions = []
                autocompleteMode = mentionSuggestions.isEmpty ? nil : .users
            case "#":
                let result = try await appState.search(query: query, type: "hashtags")
                hashtagSuggestions = Array((result.hashtags ?? []).prefix(16))
                mentionSuggestions = []
                autocompleteMode = hashtagSuggestions.isEmpty ? nil : .hashtags
            default:
                autocompleteMode = nil
                mentionSuggestions = []
                hashtagSuggestions = []
            }
        } catch {
            autocompleteMode = nil
            mentionSuggestions = []
            hashtagSuggestions = []
        }
    }

    private func applyHashtagSuggestion(_ hashtag: Hashtag) {
        replaceAutocompleteToken(with: "#\(hashtag.name)")
    }

    private func applyMentionSuggestion(_ user: User) {
        guard let userName = user.userName?.trimmingPrefix("@").nilIfEmpty else {
            return
        }

        replaceAutocompleteToken(with: "@\(userName)")
    }

    private func replaceAutocompleteToken(with replacement: String) {
        if let range = statusText.range(of: "([#@][A-Za-z0-9_\\.-]*)$", options: .regularExpression) {
            statusText.replaceSubrange(range, with: "\(replacement) ")
        } else {
            let needsSpace = !statusText.isEmpty && !statusText.hasSuffix(" ")
            statusText += (needsSpace ? " " : "") + "\(replacement) "
        }

        autocompleteMode = nil
        mentionSuggestions = []
        hashtagSuggestions = []
        isTextFocused = true
    }

    private func bindingForAttachment(id: UUID) -> Binding<ComposeStatusAttachment>? {
        guard let index = attachments.firstIndex(where: { $0.id == id }) else {
            return nil
        }

        return $attachments[index]
    }

    private func resizedImageForAttachmentSelection(_ image: UIImage) -> UIImage {
        let originalSize = image.size
        let maxOriginal = max(originalSize.width, originalSize.height)

        guard maxOriginal > maxAttachmentLongestEdge, maxOriginal > 0 else {
            return image
        }

        let scale = maxAttachmentLongestEdge / maxOriginal
        let targetSize = CGSize(width: originalSize.width * scale, height: originalSize.height * scale)

        return image.resized(to: targetSize)
    }

    private func preparedAttachmentPayload(fromFileURL fileURL: URL) -> (image: UIImage, data: Data)? {
        let pixelLimit = max(1, Int(maxAttachmentLongestEdge.rounded()))
        guard let downsampledData = UIImage.downsampledJpegData(from: fileURL, maxPixelSize: pixelLimit),
              let downsampledImage = UIImage(data: downsampledData) else {
            return nil
        }

        guard let convertedData = downsampledImage.convertToExtendedSRGBJpeg(),
              let convertedImage = UIImage(data: convertedData) else {
            return (downsampledImage, downsampledData)
        }

        return (convertedImage, convertedData)
    }

    private func preparedAttachmentPayload(from sourceData: Data) -> (image: UIImage, data: Data)? {
        guard let image = UIImage(data: sourceData) else {
            return nil
        }

        return preparedAttachmentPayload(from: image)
    }

    private func preparedAttachmentPayload(from image: UIImage) -> (image: UIImage, data: Data)? {
        let resizedImage = resizedImageForAttachmentSelection(image)
        guard let convertedData = resizedImage.convertToExtendedSRGBJpeg(),
              let convertedImage = UIImage(data: convertedData) else {
            return nil
        }

        return (convertedImage, convertedData)
    }

    @MainActor
    private func validatePreparedAttachmentSizeLimit(_ preparedData: Data) -> Bool {
        guard let limit = maxAttachmentImageSizeLimitBytes, limit > 0 else {
            return true
        }

        guard preparedData.count <= limit else {
            errorMessage = "Selected photo is too large. Maximum allowed size is \(imageSizeLimitLabel(bytes: limit))."
            return false
        }

        return true
    }

    private func imageSizeLimitLabel(bytes: Int) -> String {
        let mebibytes = Double(bytes) / (1024.0 * 1024.0)
        if mebibytes.rounded() == mebibytes {
            return "\(Int(mebibytes)) MiB"
        }

        return String(format: "%.1f MiB", mebibytes)
    }
}
