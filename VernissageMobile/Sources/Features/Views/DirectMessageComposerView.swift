//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct DirectMessageComposerView: View {
    @Environment(AppState.self) private var appState
    @Bindable var model: DirectConversationViewModel
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 8) {
            if !model.attachments.isEmpty {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(model.attachments, id: \.id) { attachment in
                            VStack {
                                AsyncImage(url: URL(string: attachment.previewUrl ?? attachment.url ?? "")) { image in
                                    image.resizable().scaledToFit()
                                } placeholder: {
                                    Image(systemName: "photo")
                                }
                                .frame(width: 70, height: 70)
                                Button("Remove photo", systemImage: "xmark.circle") {
                                    Task {
                                        await model.removeAttachment(attachment, using: appState)
                                    }
                                }
                                .labelStyle(.iconOnly)
                                .disabled(model.isBusy)
                            }
                        }
                    }
                }
            }

            if model.isReady && !model.emailVerified {
                Text("Verify your email address to send direct messages.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .bottom, spacing: 10) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Attach photo", systemImage: "photo")
                        .labelStyle(.iconOnly)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .disabled(!model.isReady || !model.emailVerified || model.recipients.isEmpty || model.isBusy
                          || model.attachments.count >= model.maxAttachments(using: appState))
                TextField("Write a message…", text: $model.note, axis: .vertical)
                    .lineLimit(1...6)
                    .padding(10)
                    .background(.quaternary, in: .rect(cornerRadius: 16))
                    .disabled(!model.isReady || !model.emailVerified || model.recipients.isEmpty || model.isSending)
                Button {
                    Task {
                        await model.send(using: appState)
                    }
                } label: {
                    Label("Send message", systemImage: "paperplane.fill")
                        .labelStyle(.iconOnly)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .disabled(!model.canSend(using: appState))
            }

            if model.isBusy {
                ProgressView()
            }

            if model.note.count > model.maxCharacters(using: appState) {
                Text("\(model.note.count)/\(model.maxCharacters(using: appState))")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(.bar)
        .task(id: selectedPhoto) {
            guard let selectedPhoto else {
                return
            }

            do {
                guard let type = selectedPhoto.supportedContentTypes.first,
                      type.conforms(to: .image), let mime = type.preferredMIMEType,
                      let data = try await selectedPhoto.loadTransferable(type: Data.self) else {
                    return
                }

                try Task.checkCancellation()
                await model.upload(data: data, fileName: "message-image.\(type.preferredFilenameExtension ?? "jpg")",
                                   mimeType: mime, using: appState)
                self.selectedPhoto = nil
            } catch {
                if !Task.isCancelled {
                    model.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
