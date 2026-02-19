//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct SharedBusinessCardQRCodeSheet: View {
    @Environment(\.dismiss) private var dismiss

    let urlString: String

    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    private var qrImage: UIImage? {
        let payload = Data(urlString.utf8)
        filter.setValue(payload, forKey: "inputMessage")
        filter.correctionLevel = "Q"

        guard let outputImage = filter.outputImage else {
            return nil
        }

        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let qrImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(uiColor: .secondarySystemBackground))
                        )
                } else {
                    ContentUnavailableView("Cannot generate QR code",
                                           systemImage: "qrcode",
                                           description: Text("Try again in a moment."))
                }

                if let url = URL(string: urlString) {
                    Link(url.absoluteString, destination: url)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 10)
                } else {
                    Text(urlString)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle("Shared card QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.fraction(0.46), .medium])
        .presentationDragIndicator(.visible)
    }
}
