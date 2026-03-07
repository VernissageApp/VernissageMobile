//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ProfileEditSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let profile: User
    let onSaved: (User) -> Void

    @State private var name: String
    @State private var bio: String
    @State private var selectedLocale: String
    @State private var manuallyApprovesFollowers: Bool
    @State private var includePublicPostsInSearchEngines: Bool
    @State private var includeProfilePageInSearchEngines: Bool
    @State private var fields: [ProfileEditField]

    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var isBioFocused: Bool

    private let maxNameLength = 100
    private let maxBioLength = 500
    private let maxFieldLength = 500

    init(profile: User, onSaved: @escaping (User) -> Void) {
        self.profile = profile
        self.onSaved = onSaved

        _name = State(initialValue: profile.name ?? "")
        _bio = State(initialValue: profile.bio ?? "")
        _selectedLocale = State(initialValue: profile.locale?.nilIfEmpty ?? "en_US")
        _manuallyApprovesFollowers = State(initialValue: profile.manuallyApprovesFollowers ?? false)
        _includePublicPostsInSearchEngines = State(initialValue: profile.includePublicPostsInSearchEngines ?? false)
        _includeProfilePageInSearchEngines = State(initialValue: profile.includeProfilePageInSearchEngines ?? false)
        _fields = State(initialValue: (profile.fields ?? []).map {
            ProfileEditField(
                backendId: $0.id,
                key: $0.key ?? "",
                value: $0.value ?? ""
            )
        })
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Enter your displayed name", text: $name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .onChange(of: name) { _, newValue in
                            if newValue.count > maxNameLength {
                                name = String(newValue.prefix(maxNameLength))
                            }
                        }
                } header: {
                    Text("Name")
                } footer: {
                    Text("\(name.count)/\(maxNameLength)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                Section {
                    TextEditor(text: $bio)
                        .focused($isBioFocused)
                        .frame(minHeight: 120)
                        .onChange(of: bio) { _, newValue in
                            if newValue.count > maxBioLength {
                                bio = String(newValue.prefix(maxBioLength))
                            }
                        }
                } header: {
                    Text("Bio")
                } footer: {
                    Text("\(bio.count)/\(maxBioLength)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                Picker("Language", selection: $selectedLocale) {
                    ForEach(localeOptions, id: \.code) { option in
                        Text(option.label).tag(option.code)
                    }
                }

                Section("Visibility") {
                    Toggle("Manually accept new followers", isOn: $manuallyApprovesFollowers)
                        .tint(.blue)
                    Toggle("Include public posts in search engines", isOn: $includePublicPostsInSearchEngines)
                        .tint(.blue)
                    Toggle("Include profile page in search engines", isOn: $includeProfilePageInSearchEngines)
                        .tint(.blue)
                }

                if fields.isEmpty {
                    Text("No fields.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(fields.indices, id: \.self) { index in
                        Section {
                            TextField("Key", text: $fields[index].key)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .onChange(of: fields[index].key) { _, newValue in
                                    if newValue.count > maxFieldLength {
                                        fields[index].key = String(newValue.prefix(maxFieldLength))
                                    }
                                }
                            
                            TextField("Value", text: $fields[index].value)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .onChange(of: fields[index].value) { _, newValue in
                                    if newValue.count > maxFieldLength {
                                        fields[index].value = String(newValue.prefix(maxFieldLength))
                                    }
                                }
                        } header: {
                            
                        } footer: {
                            Button(role: .destructive) {
                                fields.remove(at: index)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                }

                Section {
                    Button("Add field") {
                        fields.append(ProfileEditField(backendId: nil, key: "", value: ""))
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await saveProfile() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .task {
                try? await Task.sleep(for: .milliseconds(150))
                isBioFocused = true
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .errorAlertToast($errorMessage)
    }

    private var localeOptions: [(code: String, label: String)] {
        var options: [(code: String, label: String)] = [
            ("en_US", "English (English)"),
            ("pl_PL", "Polish (polski)")
        ]

        if options.contains(where: { $0.code == selectedLocale }) == false,
           selectedLocale.nilIfEmpty != nil {
            options.insert((selectedLocale, selectedLocale), at: 0)
        }

        return options
    }

    @MainActor
    private func saveProfile() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)

        let payloadFields: [UpdateProfileFlexiField] = fields.compactMap { field in
            let trimmedKey = field.key.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedValue = field.value.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmedKey.nilIfEmpty == nil && trimmedValue.nilIfEmpty == nil {
                return nil
            }

            return UpdateProfileFlexiField(
                id: field.backendId?.nilIfEmpty,
                key: trimmedKey.nilIfEmpty,
                value: trimmedValue.nilIfEmpty
            )
        }

        let request = UpdateProfileRequest(
            name: trimmedName.nilIfEmpty,
            bio: trimmedBio.nilIfEmpty,
            locale: selectedLocale.nilIfEmpty,
            manuallyApprovesFollowers: manuallyApprovesFollowers,
            includePublicPostsInSearchEngines: includePublicPostsInSearchEngines,
            includeProfilePageInSearchEngines: includeProfilePageInSearchEngines,
            fields: payloadFields
        )

        isSaving = true
        defer { isSaving = false }

        do {
            let updatedProfile = try await appState.updateActiveProfile(request: request)
            onSaved(updatedProfile)
            errorMessage = nil
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
