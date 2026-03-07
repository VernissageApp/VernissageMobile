//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI
import PhotosUI

struct ProfileHeaderSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let profile: User
    let onSaved: (User) -> Void

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedHeaderImage: UIImage?
    @State private var currentHeaderURL: String?
    @State private var isLoadingPhoto = false
    @State private var isSaving = false
    @State private var isRemoving = false
    @State private var errorMessage: String?

    init(profile: User, onSaved: @escaping (User) -> Void) {
        self.profile = profile
        self.onSaved = onSaved
        _currentHeaderURL = State(initialValue: profile.headerUrl?.nilIfEmpty)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("PNG, GIF or JPG. At most 2 MiB. The image will be downscaled before upload.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)

                headerPreview
                    .frame(maxWidth: 360)
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack(spacing: 10) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("Choose photo", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(.borderedProminent)

                    Button(role: .destructive) {
                        Task { await removeHeader() }
                    } label: {
                        if isRemoving {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "trash")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isSaving || isRemoving || currentHeaderURL?.nilIfEmpty == nil)
                    .accessibilityLabel("Remove header")
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
                } else if selectedHeaderImage != nil {
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
            .navigationTitle("Change header")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await saveHeader() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isLoadingPhoto || isSaving || isRemoving || selectedHeaderImage == nil)
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
    private var headerPreview: some View {
        ZStack {
            if let selectedHeaderImage {
                Image(uiImage: selectedHeaderImage)
                    .resizable()
                    .scaledToFit()
            } else if let currentHeaderURL = currentHeaderURL?.nilIfEmpty,
                      let headerURL = URL(string: currentHeaderURL) {
                AsyncImage(url: headerURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .failure:
                        headerPlaceholderView
                    case .empty:
                        ProgressView()
                            .tint(.secondary)
                    @unknown default:
                        headerPlaceholderView
                    }
                }
            } else {
                headerPlaceholderView
            }
        }
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.5), lineWidth: 1)
        )
    }

    private var headerPlaceholderView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))

            Image(systemName: "photo")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary)
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

            selectedHeaderImage = image
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    @MainActor
    private func saveHeader() async {
        guard let selectedHeaderImage else {
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            guard let uploadData = preparedHeaderData(from: selectedHeaderImage) else {
                errorMessage = "Cannot prepare selected photo for upload."
                return
            }

            guard uploadData.count <= AppConstants.MediaUpload.profileMaxUploadBytes else {
                errorMessage = "Selected photo is too large. Choose a smaller image."
                return
            }

            let updatedProfile = try await appState.uploadActiveHeader(
                imageData: uploadData,
                fileName: "header.jpg",
                mimeType: "image/jpeg"
            )

            currentHeaderURL = updatedProfile.headerUrl?.nilIfEmpty
            onSaved(updatedProfile)
            errorMessage = nil
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    @MainActor
    private func removeHeader() async {
        guard currentHeaderURL?.nilIfEmpty != nil else {
            return
        }

        isRemoving = true
        defer { isRemoving = false }

        do {
            let updatedProfile = try await appState.deleteActiveHeader()
            currentHeaderURL = updatedProfile.headerUrl?.nilIfEmpty
            selectedHeaderImage = nil
            selectedPhotoItem = nil
            onSaved(updatedProfile)
            errorMessage = nil
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func preparedHeaderData(from image: UIImage) -> Data? {
        let resizedImage = resizedImageForHeader(image)
        var compressionQuality: CGFloat = 0.9

        guard var data = resizedImage.jpegData(compressionQuality: compressionQuality) else {
            return nil
        }

        while data.count > AppConstants.MediaUpload.profileMaxUploadBytes && compressionQuality > 0.2 {
            compressionQuality -= 0.1

            guard let compressed = resizedImage.jpegData(compressionQuality: compressionQuality) else {
                break
            }

            data = compressed
        }

        return data
    }

    private func resizedImageForHeader(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 2200
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
