//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct InstanceInformationScreen: View {
    @Environment(AppState.self) private var appState

    @State private var instance: InstanceDetails?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading && instance == nil {
                ProgressView()
                    .tint(.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                List {
                    if let markdown = instance?.longDescriptionMarkdown?.nilIfEmpty {
                        Section("Instance message") {
                            MarkdownFormattedTextView(markdown)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.vertical, 2)
                        }
                    }

                    if let details = instance {
                        Section("Instance information") {
                            if let title = details.title?.nilIfEmpty {
                                LabeledContent("Title") {
                                    Text(title)
                                        .multilineTextAlignment(.trailing)
                                }
                            }

                            if let description = details.description?.nilIfEmpty {
                                LabeledContent("Description") {
                                    Text(description)
                                        .multilineTextAlignment(.trailing)
                                }
                            }

                            if let version = details.version?.nilIfEmpty {
                                LabeledContent("API version") {
                                    Text(version)
                                }
                            }

                            if let languages = details.languages, !languages.isEmpty {
                                LabeledContent("Languages") {
                                    Text(languages.joined(separator: ", "))
                                }
                            }

                            LabeledContent("Max status characters") {
                                Text("\(details.configuration?.statuses?.maxCharacters ?? 0)")
                            }

                            LabeledContent("Max media attachments") {
                                Text("\(details.configuration?.statuses?.maxMediaAttachments ?? 0)")
                            }

                            if let imageSizeLimitLabel = imageSizeLimitLabel(bytes: details.configuration?.attachments?.imageSizeLimit) {
                                LabeledContent("Image size limit") {
                                    Text(imageSizeLimitLabel)
                                }
                            }

                            if let email = details.email?.nilIfEmpty {
                                LabeledContent("Email") {
                                    if let emailURL = URL(string: "mailto:\(email)") {
                                        Link(email, destination: emailURL)
                                    } else {
                                        Text(email)
                                    }
                                }
                            }
                        }
                        
                        if let contact = details.contact {
                            Section("Contact account") {
                                InstanceContactCompactRowView(user: contact)
                            }
                        }
                    } else {
                        ContentUnavailableView("No instance information",
                                               systemImage: "building.2",
                                               description: Text("Cannot load instance details right now."))
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Instance")
        .navigationBarTitleDisplayMode(.inline)
        .onFirstAppear {
            guard instance == nil else {
                return
            }

            await loadInstance()
        }
        .refreshable {
            await loadInstance()
        }
        .errorAlertToast($errorMessage)
    }

    @MainActor
    private func loadInstance() async {
        isLoading = true
        defer { isLoading = false }

        do {
            instance = try await appState.api.instance.fetchInstanceDetails()
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func imageSizeLimitLabel(bytes: Int?) -> String? {
        guard let bytes, bytes > 0 else {
            return nil
        }

        let mebibytes = Double(bytes) / (1024.0 * 1024.0)
        if mebibytes.rounded() == mebibytes {
            return "\(Int(mebibytes)) MiB"
        }

        return mebibytes.formatted(.number.precision(.fractionLength(1))) + " MiB"
    }
}
