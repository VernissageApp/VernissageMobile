//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct AttachmentMetadataSectionView: View {
    let attachment: Attachment
    let altText: String?
    let categoryName: String?
    var onCategoryTap: (() -> Void)? = nil

    private var exif: AttachmentExif? {
        attachment.metadata?.exif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let altText = altText?.nilIfEmpty {
                MetadataLineView(systemImage: "eye") {
                    Text(altText)
                        .italic()
                }
            }

            if let categoryName = categoryName?.nilIfEmpty {
                MetadataLineView(systemImage: "tag") {
                    if let onCategoryTap {
                        Button(action: onCategoryTap) {
                            Text(categoryName)
                                .fontWeight(.semibold)
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(categoryName)
                            .fontWeight(.semibold)
                    }
                }
            }

            if let locationLabel = attachment.locationDisplayLabel {
                MetadataLineView(systemImage: "mappin.and.ellipse") {
                    if let mapURL = attachment.openStreetMapURL {
                        Link(locationLabel, destination: mapURL)
                            .foregroundStyle(.blue)
                    } else {
                        Text(locationLabel)
                    }
                }
            }

            if let licenseLabel = attachment.licenseDisplayLabel {
                MetadataLineView(systemImage: "checkmark.seal") {
                    if let licenseURL = attachment.license?.url?.nilIfEmpty,
                       let url = URL(string: licenseURL) {
                        Link(licenseLabel, destination: url)
                            .foregroundStyle(.blue)
                    } else {
                        Text(licenseLabel)
                    }
                }
            }

            if let cameraLabel = exif?.cameraDisplayLabel {
                MetadataLineView(systemImage: "camera") {
                    Text(cameraLabel)
                }
            }

            if let lens = exif?.lens?.nilIfEmpty {
                MetadataLineView(systemImage: "camera.aperture") {
                    Text(lens)
                }
            }

            if let exposureLabel = exif?.exposureDisplayLabel {
                MetadataLineView(systemImage: "sun.max") {
                    Text(exposureLabel)
                }
            }

            if let flash = exif?.flash?.nilIfEmpty {
                MetadataLineView(systemImage: "bolt") {
                    Text(flash)
                }
            }

            if let software = exif?.software?.nilIfEmpty {
                MetadataLineView(systemImage: "slider.horizontal.3") {
                    Text(software)
                }
            }

            if let film = exif?.film?.nilIfEmpty {
                MetadataLineView(systemImage: "film") {
                    Text(film)
                }
            }

            if let chemistry = exif?.chemistry?.nilIfEmpty {
                MetadataLineView(systemImage: "flask") {
                    Text(chemistry)
                }
            }

            if let scanner = exif?.scanner?.nilIfEmpty {
                MetadataLineView(systemImage: "scanner") {
                    Text(scanner)
                }
            }

            if let createdDate = exif?.createDateDisplayLabel {
                MetadataLineView(systemImage: "calendar") {
                    Text(createdDate)
                }
            }
        }
        .font(.subheadline)
        .foregroundStyle(.primary)
        .padding(.top, 2)
    }
}
