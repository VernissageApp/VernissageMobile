//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI
import PhotosUI

struct ProfileAvatarSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let profile: User
    let onSaved: (User) -> Void

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedAvatarImage: UIImage?
    @State private var currentAvatarURL: String?
    @State private var isLoadingPhoto = false
    @State private var isSaving = false
    @State private var isRemoving = false
    @State private var errorMessage: String?

    private let maxUploadBytes = 2 * 1024 * 1024

    init(profile: User, onSaved: @escaping (User) -> Void) {
        self.profile = profile
        self.onSaved = onSaved
        _currentAvatarURL = State(initialValue: profile.avatarUrl?.nilIfEmpty)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("PNG, GIF or JPG. At most 2 MiB. The image will be downscaled before upload.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)

                avatarPreview
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack(spacing: 10) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("Choose photo", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(.borderedProminent)

                    Button(role: .destructive) {
                        Task { await removeAvatar() }
                    } label: {
                        if isRemoving {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "trash")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isSaving || isRemoving || currentAvatarURL?.nilIfEmpty == nil)
                    .accessibilityLabel("Remove avatar")
                }
                .frame(maxWidth: 360)
                .frame(maxWidth: .infinity, alignment: .center)

                if isLoadingPhoto {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading photo...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: 360)
                    .frame(maxWidth: .infinity, alignment: .center)
                } else if selectedAvatarImage != nil {
                    Text("Photo selected. Tap Save to upload.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 360)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .navigationTitle("Change avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await saveAvatar() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isLoadingPhoto || isSaving || isRemoving || selectedAvatarImage == nil)
                }
            }
        }
        .onChange(of: selectedPhotoItem, initial: false) { _, newItem in
            Task {
                await loadPhoto(from: newItem)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .errorAlertToast($errorMessage)
    }

    @ViewBuilder
    private var avatarPreview: some View {
        if let selectedAvatarImage {
            Image(uiImage: selectedAvatarImage)
                .resizable()
                .scaledToFill()
                .frame(width: 136, height: 136)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color(uiColor: .separator).opacity(0.5), lineWidth: 1)
                )
        } else {
            AsyncAvatarView(urlString: currentAvatarURL, size: 136)
                .overlay(
                    Circle()
                        .stroke(Color(uiColor: .separator).opacity(0.5), lineWidth: 1)
                )
        }
    }

    @MainActor
    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else {
            return
        }

        isLoadingPhoto = true
        defer { isLoadingPhoto = false }

        do {
            guard let photoData = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: photoData) else {
                errorMessage = "Cannot read selected photo."
                return
            }

            selectedAvatarImage = image
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    @MainActor
    private func saveAvatar() async {
        guard let selectedAvatarImage else {
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            guard let uploadData = preparedAvatarData(from: selectedAvatarImage) else {
                errorMessage = "Cannot prepare selected photo for upload."
                return
            }

            guard uploadData.count <= maxUploadBytes else {
                errorMessage = "Selected photo is too large. Choose a smaller image."
                return
            }

            let updatedProfile = try await appState.uploadActiveAvatar(
                imageData: uploadData,
                fileName: "avatar.jpg",
                mimeType: "image/jpeg"
            )

            currentAvatarURL = updatedProfile.avatarUrl?.nilIfEmpty
            onSaved(updatedProfile)
            errorMessage = nil
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    @MainActor
    private func removeAvatar() async {
        guard currentAvatarURL?.nilIfEmpty != nil else {
            return
        }

        isRemoving = true
        defer { isRemoving = false }

        do {
            let updatedProfile = try await appState.deleteActiveAvatar()
            currentAvatarURL = updatedProfile.avatarUrl?.nilIfEmpty
            selectedAvatarImage = nil
            selectedPhotoItem = nil
            onSaved(updatedProfile)
            errorMessage = nil
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func preparedAvatarData(from image: UIImage) -> Data? {
        let resizedImage = resizedImageForAvatar(image)
        var compressionQuality: CGFloat = 0.9

        guard var data = resizedImage.jpegData(compressionQuality: compressionQuality) else {
            return nil
        }

        while data.count > maxUploadBytes && compressionQuality > 0.2 {
            compressionQuality -= 0.1

            guard let compressed = resizedImage.jpegData(compressionQuality: compressionQuality) else {
                break
            }

            data = compressed
        }

        return data
    }

    private func resizedImageForAvatar(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 1200
        let size = image.size
        let largestDimension = max(size.width, size.height)

        guard largestDimension > maxDimension, largestDimension > 0 else {
            return image
        }

        let scale = maxDimension / largestDimension
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)

        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
