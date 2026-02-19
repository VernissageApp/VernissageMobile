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

    @Environment(\.dismiss) private var dismiss

    @State private var cityQuery: String
    @State private var citySuggestions: [Location] = []
    @State private var isSearchingCity = false
    @State private var isGeneratingDescription = false
    @State private var citySearchTask: Task<Void, Never>?
    @State private var errorMessage: String?

    init(
        attachment: Binding<ComposeStatusAttachment>,
        licenses: [License],
        countries: [Country],
        isOpenAIEnabled: Bool,
        citySearch: @escaping (_ countryCode: String, _ query: String) async throws -> [Location],
        generateDescription: @escaping (_ attachmentId: String) async throws -> String?
    ) {
        _attachment = attachment
        self.licenses = licenses
        self.countries = countries
        self.isOpenAIEnabled = isOpenAIEnabled
        self.citySearch = citySearch
        self.generateDescription = generateDescription
        _cityQuery = State(initialValue: attachment.wrappedValue.cityName)
    }

    var body: some View {
        NavigationStack {
            Form {
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
                            ForEach(Array(citySuggestions.enumerated()), id: \.offset) { _, location in
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
            }
            .navigationTitle("Photo details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .errorAlertToast($errorMessage)
    }

    private var sortedCountries: [Country] {
        countries.sorted { ($0.name ?? "") < ($1.name ?? "") }
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
            try? await Task.sleep(nanoseconds: 300_000_000)
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
}
