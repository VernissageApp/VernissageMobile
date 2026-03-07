//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct StatusAttachmentViewerScreen: View {
    @Environment(\.dismiss) private var dismiss

    let attachments: [Attachment]
    let initialIndex: Int

    @State private var selectedIndex: Int
    @State private var verticalDismissOffset: CGFloat = 0
    @State private var isCurrentAttachmentZoomed = false
    @State private var dominantBackgroundColors: [Int: UIColor] = [:]

    init(attachments: [Attachment], initialIndex: Int) {
        self.attachments = attachments
        self.initialIndex = initialIndex

        let maxIndex = max(attachments.count - 1, 0)
        _selectedIndex = State(initialValue: min(max(initialIndex, 0), maxIndex))
    }

    var body: some View {
        ZStack {
            Color(uiColor: currentBackgroundColor)
                .ignoresSafeArea()

            if attachments.isEmpty {
                ContentUnavailableView("No photo", systemImage: "photo")
                    .foregroundStyle(.white.opacity(0.8))
            } else {
                TabView(selection: $selectedIndex) {
                    ForEach(attachments.indices, id: \.self) { index in
                        let attachment = attachments[index]
                        ZoomableStatusAttachmentView(
                            attachment: attachment,
                            backgroundColor: Color(uiColor: currentBackgroundColor)
                        ) { isZoomed in
                            guard selectedIndex == index else {
                                return
                            }

                            if isCurrentAttachmentZoomed != isZoomed {
                                isCurrentAttachmentZoomed = isZoomed
                            }
                        } onDominantColorChanged: { dominantColor in
                            withAnimation(.easeInOut(duration: 0.25)) {
                                dominantBackgroundColors[index] = dominantColor.tonedPhotoBackdropColor
                            }
                        }
                            .tag(index)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 24)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: attachments.count > 1 ? .automatic : .never))
                .indexViewStyle(.page(backgroundDisplayMode: .interactive))
                .offset(y: verticalDismissOffset)
                .onChange(of: selectedIndex, initial: false) { _, _ in
                    isCurrentAttachmentZoomed = false
                }
            }

            VStack(spacing: 0) {
                HStack {
                    Spacer(minLength: 0)

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32, weight: .regular))
                            .foregroundStyle(.white.opacity(0.92))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 16)
                    .padding(.top, 10)
                }

                Spacer(minLength: 0)
            }
        }
        .statusBarHidden()
        .simultaneousGesture(dismissGesture)
    }

    private var currentBackgroundColor: UIColor {
        dominantBackgroundColors[selectedIndex] ?? .black
    }

    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .onChanged { value in
                guard !isCurrentAttachmentZoomed else {
                    return
                }

                guard abs(value.translation.height) > abs(value.translation.width) else {
                    return
                }

                verticalDismissOffset = value.translation.height
            }
            .onEnded { value in
                guard !isCurrentAttachmentZoomed else {
                    verticalDismissOffset = 0
                    return
                }

                guard abs(value.translation.height) > abs(value.translation.width) else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        verticalDismissOffset = 0
                    }
                    return
                }

                let shouldDismiss = abs(value.translation.height) > 140 || abs(value.predictedEndTranslation.height) > 260
                if shouldDismiss {
                    dismiss()
                } else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        verticalDismissOffset = 0
                    }
                }
            }
    }
}
