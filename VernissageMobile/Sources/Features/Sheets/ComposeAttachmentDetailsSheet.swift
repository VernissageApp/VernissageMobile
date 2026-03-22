//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ComposeAttachmentDetailsSheet: View {
    @Binding var attachment: ComposeStatusAttachment
    let licenses: [License]
    let countries: [Country]
    let isOpenAIEnabled: Bool
    let citySearch: (_ countryCode: String, _ query: String) async throws -> [Location]
    let generateDescription: (_ attachmentId: String) async throws -> String?
    let onDeleteAttachment: (_ attachmentId: UUID) async -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppConstants.StorageKeys.composeAttachmentDetailsLicenseId) private var rememberedLicenseId = ""
    @AppStorage(AppConstants.StorageKeys.composeAttachmentDetailsCountryCode) private var rememberedCountryCode = ""
    @AppStorage(AppConstants.StorageKeys.composeAttachmentDetailsCountryName) private var rememberedCountryName = ""
    @AppStorage(AppConstants.StorageKeys.composeAttachmentDetailsCityName) private var rememberedCityName = ""
    @AppStorage(AppConstants.StorageKeys.composeAttachmentDetailsLocationId) private var rememberedLocationId = ""

    @State private var cityQuery: String
    @State private var citySuggestions: [Location] = []
    @State private var isSearchingCity = false
    @State private var isGeneratingDescription = false
    @State private var citySearchTask: Task<Void, Never>?
    @State private var errorMessage: String?
    @State private var isDeletingAttachment = false
    @State private var didApplyRememberedValues = false
    @State private var shouldIgnoreNextCityQueryChange = false
    @State private var attachmentViewerPayload: ComposeAttachmentViewerPayload?

    init(
        attachment: Binding<ComposeStatusAttachment>,
        licenses: [License],
        countries: [Country],
        isOpenAIEnabled: Bool,
        citySearch: @escaping (_ countryCode: String, _ query: String) async throws -> [Location],
        generateDescription: @escaping (_ attachmentId: String) async throws -> String?,
        onDeleteAttachment: @escaping (_ attachmentId: UUID) async -> Void
    ) {
        _attachment = attachment
        self.licenses = licenses
        self.countries = countries
        self.isOpenAIEnabled = isOpenAIEnabled
        self.citySearch = citySearch
        self.generateDescription = generateDescription
        self.onDeleteAttachment = onDeleteAttachment
        _cityQuery = State(initialValue: attachment.wrappedValue.cityName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    attachmentPreviewHeader
                } footer: {
                    if let uploadResolutionFootnoteText {
                        Text(uploadResolutionFootnoteText)
                    }
                }

                if isOpenAIEnabled {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Button {
                                Task {
                                    await generateAltText()
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    if isGeneratingDescription {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "sparkles")
                                    }

                                    Text(isGeneratingDescription ? "Generating..." : "Generate ALT text")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(attachment.serverId?.nilIfEmpty == nil || attachment.isUploading || isGeneratingDescription)

                            Text("Feature powered by OpenAI.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    TextEditor(text: $attachment.altText)
                        .frame(minHeight: 130)
                } header: {
                    Text("Alt text")
                } footer: {
                    Text("\(attachment.altText.count)/2000")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                Section("License") {
                    Picker("License", selection: Binding(
                        get: { attachment.licenseId ?? "" },
                        set: { attachment.licenseId = $0.nilIfEmpty }
                    )) {
                        Text("Without a license").tag("")
                        ForEach(licenses, id: \.id) { license in
                            Text(licenseDisplayName(for: license))
                                .tag(license.id)
                        }
                    }
                }

                Section("Location") {
                    Menu {
                        Button("No country") {
                            attachment.countryCode = nil
                            attachment.countryName = nil
                            attachment.locationId = nil
                            attachment.cityName = ""
                            cityQuery = ""
                            citySuggestions = []
                        }

                        Divider()

                        ForEach(sortedCountries, id: \.self) { country in
                            Button {
                                attachment.countryCode = country.code?.nilIfEmpty
                                attachment.countryName = country.name?.nilIfEmpty
                                attachment.locationId = nil
                                attachment.cityName = ""
                                cityQuery = ""
                                citySuggestions = []
                            } label: {
                                Text(countryLabel(country))
                            }
                        }
                    } label: {
                        HStack {
                            Text("Country")
                                .foregroundStyle(.primary)
                            Spacer(minLength: 8)
                            Text(countryValueLabel)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    TextField("City", text: $cityQuery)
                        .onChange(of: cityQuery, initial: false) { _, newValue in
                            if shouldIgnoreNextCityQueryChange {
                                shouldIgnoreNextCityQueryChange = false
                                return
                            }

                            let normalizedNewValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            let normalizedCurrentCity = attachment.cityName.trimmingCharacters(in: .whitespacesAndNewlines)
                            if normalizedNewValue == normalizedCurrentCity,
                               attachment.locationId?.nilIfEmpty != nil {
                                return
                            }

                            attachment.cityName = newValue
                            attachment.locationId = nil
                            scheduleCitySearch(query: newValue)
                        }

                    if isSearchingCity {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Searching...")
                                .foregroundStyle(.secondary)
                        }
                    } else if !citySuggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(citySuggestions.indices, id: \.self) { index in
                                let location = citySuggestions[index]
                                Button {
                                    attachment.cityName = location.name?.nilIfEmpty ?? cityQuery
                                    cityQuery = attachment.cityName
                                    attachment.locationId = location.id?.nilIfEmpty
                                    citySuggestions = []
                                } label: {
                                    HStack {
                                        Text(location.name?.nilIfEmpty ?? "Unknown")
                                            .foregroundStyle(.primary)
                                        Spacer(minLength: 8)
                                        if let countryName = location.country?.name?.nilIfEmpty {
                                            Text(countryName)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Section("Exif metadata") {
                    Toggle("GPS coordinates", isOn: $attachment.showGpsCoordinates)
                    
                    HStack(spacing: 10) {
                        TextField("Latitude", text: $attachment.latitude)
                            .disabled(!attachment.showGpsCoordinates)
                        TextField("Longitude", text: $attachment.longitude)
                            .disabled(!attachment.showGpsCoordinates)
                    }
                }

                Section {
                    exifRow(title: "Manufacturer", isOn: $attachment.showMake, text: $attachment.make)
                    exifRow(title: "Model", isOn: $attachment.showModel, text: $attachment.model)
                    exifRow(title: "Lens", isOn: $attachment.showLens, text: $attachment.lens)
                    exifRow(title: "Focal length", isOn: $attachment.showFocalLenIn35mmFilm, text: $attachment.focalLength)
                    exifRow(title: "35mm equivalent", isOn: $attachment.showFocalLenIn35mmFilm, text: $attachment.focalLenIn35mmFilm)
                    exifRow(title: "Aperture", isOn: $attachment.showFNumber, text: $attachment.fNumber)
                    exifRow(title: "Exposure time", isOn: $attachment.showExposureTime, text: $attachment.exposureTime)
                    exifRow(title: "ISO", isOn: $attachment.showPhotographicSensitivity, text: $attachment.photographicSensitivity)
                    exifRow(title: "Flash", isOn: $attachment.showFlash, text: $attachment.flash)
                    exifRow(title: "Software", isOn: $attachment.showSoftware, text: $attachment.software)
                    exifRow(title: "Film", isOn: $attachment.showFilm, text: $attachment.film)
                    exifRow(title: "Chemistry", isOn: $attachment.showChemistry, text: $attachment.chemistry)
                    exifRow(title: "Scanner", isOn: $attachment.showScanner, text: $attachment.scanner)
                    exifRow(title: "Create date", isOn: $attachment.showCreateDate, text: $attachment.createDate)
                }

                Section {
                    deletePhotoButton
                }
            }
            .navigationTitle("Photo details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        saveRememberedValuesIfNeeded()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            applyRememberedValuesIfNeeded()
        }
        .errorAlertToast($errorMessage)
        .fullScreenCover(item: $attachmentViewerPayload) { payload in
            ComposeAttachmentViewerScreen(
                attachments: payload.attachments,
                initialIndex: payload.initialIndex,
                localImages: payload.localImages
            )
        }
    }

    private var sortedCountries: [Country] {
        countries.sorted { ($0.name ?? "") < ($1.name ?? "") }
    }

    private var uploadResolutionFootnoteText: String? {
        guard let longestEdge = preparedAttachmentLongestEdge else {
            return nil
        }

#if SHARE_EXTENSION
        guard longestEdge >= (AppConstants.MediaUpload.longestEdge2K - 1) else {
            return nil
        }

        return "When shared via share extension, this photo may be uploaded with the longest edge up to 2048 px. If you need higher resolution, upload it directly in the app."
#else
        guard longestEdge >= (AppConstants.MediaUpload.longestEdge4K - 1) else {
            return nil
        }

        return "For maximum compatibility across platforms, this photo will be uploaded with the longest edge up to 4094 px."
#endif
    }

    private var preparedAttachmentLongestEdge: CGFloat? {
        guard let image = attachment.localImage else {
            return nil
        }

        return max(image.size.width, image.size.height)
    }

    private var attachmentPreviewHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            attachmentPreviewThumbnail

            VStack(alignment: .leading, spacing: 10) {
                detailRow(title: "Size", value: attachmentFileSizeLabel)
                detailRow(title: "Width", value: attachmentWidthLabel)
                detailRow(title: "Height", value: attachmentHeightLabel)
                detailRow(title: "Megapixels", value: attachmentMegapixelsLabel)
                detailRow(title: "Color space", value: attachmentColorSpaceLabel)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var attachmentPreviewThumbnail: some View {
        if attachmentViewerAttachment != nil {
            Button {
                openAttachmentViewer()
            } label: {
                attachmentPreviewThumbnailContent
            }
            .buttonStyle(.plain)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityLabel("Open photo")
            .accessibilityHint("Shows this photo in full screen")
        } else {
            attachmentPreviewThumbnailContent
        }
    }

    @ViewBuilder
    private var attachmentPreviewThumbnailContent: some View {
        if let image = attachment.localImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 120, height: 120)
                .overlay {
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
        }
    }

    private var attachmentViewerAttachment: Attachment? {
        let remoteImageURL = attachment.remoteImageURL?.nilIfEmpty
        guard remoteImageURL != nil || attachment.localImage != nil else {
            return nil
        }

        let remoteAttachmentFile = remoteImageURL.map { imageURL in
            AttachmentFile(url: imageURL, width: nil, height: nil, aspect: nil)
        }

        return Attachment(
            id: attachment.serverId?.nilIfEmpty,
            smallFile: remoteAttachmentFile,
            originalFile: remoteAttachmentFile,
            blurhash: attachment.blurhash?.nilIfEmpty,
            description: attachment.altText.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            metadata: nil,
            location: nil,
            license: nil
        )
    }

    private var attachmentFileSizeLabel: String {
        guard let data = attachment.resizedImageData else {
            return "Unknown"
        }

        return formatMebibytes(bytes: data.count)
    }

    private var attachmentWidthLabel: String {
        guard let size = attachmentPixelSize else {
            return "Unknown"
        }

        return "\(size.width) px"
    }

    private var attachmentHeightLabel: String {
        guard let size = attachmentPixelSize else {
            return "Unknown"
        }

        return "\(size.height) px"
    }

    private var attachmentMegapixelsLabel: String {
        guard let size = attachmentPixelSize else {
            return "Unknown"
        }

        let megapixels = Double(size.width * size.height) / 1_000_000.0
        if megapixels >= 10 {
            return megapixels.formatted(.number.precision(.fractionLength(1))) + " MP"
        }

        return megapixels.formatted(.number.precision(.fractionLength(2))) + " MP"
    }

    private var attachmentColorSpaceLabel: String {
        guard let colorSpace = attachment.localImage?.cgImage?.colorSpace else {
            return "Unknown"
        }

        return colorSpaceDisplayName(colorSpace)
    }

    private var attachmentPixelSize: (width: Int, height: Int)? {
        guard let image = attachment.localImage else {
            return nil
        }

        if let cgImage = image.cgImage {
            return (cgImage.width, cgImage.height)
        }

        let width = Int((image.size.width * image.scale).rounded())
        let height = Int((image.size.height * image.scale).rounded())
        guard width > 0, height > 0 else {
            return nil
        }

        return (width, height)
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
        }
    }

    private func formatMebibytes(bytes: Int) -> String {
        let mebibytes = Double(bytes) / (1024.0 * 1024.0)
        return mebibytes.formatted(.number.precision(.fractionLength(2))) + " MiB"
    }

    private func colorSpaceDisplayName(_ colorSpace: CGColorSpace) -> String {
        let rawName = (colorSpace.name as String?)?.lowercased() ?? ""
        if rawName.contains("extended") && rawName.contains("srgb") {
            return "Extended sRGB"
        }
        if rawName.contains("srgb") {
            return "sRGB"
        }
        if rawName.contains("display") && rawName.contains("p3") {
            return "Display P3"
        }
        if rawName.contains("adobe") && rawName.contains("rgb") {
            return "Adobe RGB"
        }

        switch colorSpace.model {
        case .rgb:
            return "RGB"
        case .monochrome:
            return "Monochrome"
        case .cmyk:
            return "CMYK"
        case .lab:
            return "Lab"
        case .deviceN:
            return "DeviceN"
        case .indexed:
            return "Indexed"
        case .pattern:
            return "Pattern"
        case .unknown:
            return "Unknown"
        case .XYZ:
            return "XYZ"
        @unknown default:
            return "Unknown"
        }
    }

    private var countryValueLabel: String {
        if let name = attachment.countryName?.nilIfEmpty {
            return name
        }

        if let code = attachment.countryCode?.nilIfEmpty {
            return code
        }

        return "None"
    }

    private func countryLabel(_ country: Country) -> String {
        let name = country.name?.nilIfEmpty ?? "Unknown"
        if let code = country.code?.nilIfEmpty {
            return "\(name) (\(code))"
        }

        return name
    }

    private func licenseDisplayName(for license: License) -> String {
        let name = license.name?.nilIfEmpty ?? "License"
        if let code = license.code?.nilIfEmpty {
            return "\(name) (\(code))"
        }

        return name
    }

    @ViewBuilder
    private func exifRow(title: String, isOn: Binding<Bool>, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(title, isOn: isOn)
                .font(.caption)
            TextField(title, text: text)
                .disabled(!isOn.wrappedValue)
        }
    }

    private func scheduleCitySearch(query: String) {
        citySearchTask?.cancel()
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let countryCode = attachment.countryCode?.nilIfEmpty, trimmedQuery.count >= 2 else {
            citySuggestions = []
            return
        }

        citySearchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                isSearchingCity = true
            }

            do {
                let result = try await citySearch(countryCode, trimmedQuery)
                await MainActor.run {
                    citySuggestions = Array(result.prefix(10))
                    isSearchingCity = false
                }
            } catch {
                await MainActor.run {
                    citySuggestions = []
                    isSearchingCity = false
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                }
            }
        }
    }

    @MainActor
    private func generateAltText() async {
        guard !isGeneratingDescription else {
            return
        }

        guard let attachmentId = attachment.serverId?.nilIfEmpty else {
            errorMessage = "Photo must be uploaded before generating ALT text."
            return
        }

        isGeneratingDescription = true
        defer { isGeneratingDescription = false }

        do {
            let generatedDescription = try await generateDescription(attachmentId)

            guard let generated = generatedDescription?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !generated.isEmpty else {
                errorMessage = "Cannot generate ALT text for this photo."
                return
            }

            attachment.altText = generated
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func applyRememberedValuesIfNeeded() {
        guard attachment.isExistingAttachment == false, didApplyRememberedValues == false else {
            return
        }

        didApplyRememberedValues = true

        if attachment.licenseId?.nilIfEmpty == nil {
            attachment.licenseId = rememberedLicenseId.nilIfEmpty
        }

        if attachment.countryCode?.nilIfEmpty == nil {
            attachment.countryCode = rememberedCountryCode.nilIfEmpty
            attachment.countryName = rememberedCountryName.nilIfEmpty
        }

        if attachment.cityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let rememberedCity = rememberedCityName.nilIfEmpty {
            attachment.cityName = rememberedCity
            shouldIgnoreNextCityQueryChange = true
            cityQuery = rememberedCity
            attachment.locationId = rememberedLocationId.nilIfEmpty
            citySearchTask?.cancel()
            citySuggestions = []
            isSearchingCity = false
        }
    }

    private func saveRememberedValuesIfNeeded() {
        guard attachment.isExistingAttachment == false else {
            return
        }

        rememberedLicenseId = attachment.licenseId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        rememberedCountryCode = attachment.countryCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        rememberedCountryName = attachment.countryName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        rememberedCityName = attachment.cityName.trimmingCharacters(in: .whitespacesAndNewlines)
        rememberedLocationId = attachment.locationId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func openAttachmentViewer() {
        guard let attachmentViewerAttachment else {
            return
        }

        var localImages: [Int: UIImage] = [:]
        if let localImage = attachment.localImage {
            localImages[0] = localImage
        }

        attachmentViewerPayload = ComposeAttachmentViewerPayload(
            attachments: [attachmentViewerAttachment],
            initialIndex: 0,
            localImages: localImages
        )
    }

    private var deletePhotoButton: some View {
        Button(role: .destructive) {
            Task {
                await deletePhoto()
            }
        } label: {
            if isDeletingAttachment {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
            } else {
                Text("Delete photo")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.glassProminent)
        .tint(.red)
        .disabled(isDeletingAttachment)
        .accessibilityHint("Removes this photo from your post draft.")
    }

    @MainActor
    private func deletePhoto() async {
        guard !isDeletingAttachment else {
            return
        }

        isDeletingAttachment = true
        let attachmentId = attachment.id
        await onDeleteAttachment(attachmentId)
    }
}
