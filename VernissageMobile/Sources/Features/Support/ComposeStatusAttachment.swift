//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

struct ComposeStatusAttachment: Identifiable, Equatable {
    let id: UUID
    var serverId: String?
    var remoteImageURL: String?
    var localImage: UIImage?
    var originalImageData: Data?
    var blurhash: String?
    var isExistingAttachment: Bool
    var isUploading: Bool
    var uploadErrorMessage: String?

    var altText: String
    var licenseId: String?
    var countryCode: String?
    var countryName: String?
    var cityName: String
    var locationId: String?

    var showGpsCoordinates: Bool
    var latitude: String
    var longitude: String

    var showMake: Bool
    var make: String
    var showModel: Bool
    var model: String
    var showLens: Bool
    var lens: String
    var showCreateDate: Bool
    var createDate: String
    var showFocalLenIn35mmFilm: Bool
    var focalLength: String
    var focalLenIn35mmFilm: String
    var showFNumber: Bool
    var fNumber: String
    var showExposureTime: Bool
    var exposureTime: String
    var showPhotographicSensitivity: Bool
    var photographicSensitivity: String
    var showFlash: Bool
    var flash: String
    var showSoftware: Bool
    var software: String
    var showFilm: Bool
    var film: String
    var showChemistry: Bool
    var chemistry: String
    var showScanner: Bool
    var scanner: String

    var isAltMissing: Bool {
        altText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func existing(_ attachment: Attachment) -> ComposeStatusAttachment {
        let exif = attachment.metadata?.exif

        let make = exif?.make?.nilIfEmpty ?? ""
        let model = exif?.model?.nilIfEmpty ?? ""
        let lens = exif?.lens?.nilIfEmpty ?? ""
        let createDate = exif?.createDate?.nilIfEmpty ?? ""
        let focalLength = exif?.focalLength?.nilIfEmpty ?? ""
        let focalLenIn35mm = exif?.focalLenIn35mmFilm?.nilIfEmpty ?? ""
        let fNumber = exif?.fNumber?.nilIfEmpty?.replacingOccurrences(of: "f/", with: "") ?? ""
        let exposureTime = exif?.exposureTime?.nilIfEmpty ?? ""
        let iso = exif?.photographicSensitivity?.nilIfEmpty ?? ""
        let software = exif?.software?.nilIfEmpty ?? ""
        let film = exif?.film?.nilIfEmpty ?? ""
        let chemistry = exif?.chemistry?.nilIfEmpty ?? ""
        let scanner = exif?.scanner?.nilIfEmpty ?? ""
        let flash = exif?.flash?.nilIfEmpty ?? ""

        let latitude = exif?.latitude?.nilIfEmpty ?? attachment.location?.latitude?.nilIfEmpty ?? ""
        let longitude = exif?.longitude?.nilIfEmpty ?? attachment.location?.longitude?.nilIfEmpty ?? ""

        return ComposeStatusAttachment(
            id: UUID(),
            serverId: attachment.id,
            remoteImageURL: attachment.smallImageURL,
            localImage: nil,
            originalImageData: nil,
            blurhash: attachment.blurhash,
            isExistingAttachment: true,
            isUploading: false,
            uploadErrorMessage: nil,
            altText: attachment.description?.nilIfEmpty ?? "",
            licenseId: attachment.license?.id?.nilIfEmpty,
            countryCode: attachment.location?.country?.code?.nilIfEmpty,
            countryName: attachment.location?.country?.name?.nilIfEmpty,
            cityName: attachment.location?.name?.nilIfEmpty ?? "",
            locationId: attachment.location?.id?.nilIfEmpty,
            showGpsCoordinates: !latitude.isEmpty && !longitude.isEmpty,
            latitude: latitude,
            longitude: longitude,
            showMake: !make.isEmpty,
            make: make,
            showModel: !model.isEmpty,
            model: model,
            showLens: !lens.isEmpty,
            lens: lens,
            showCreateDate: !createDate.isEmpty,
            createDate: createDate,
            showFocalLenIn35mmFilm: !focalLength.isEmpty || !focalLenIn35mm.isEmpty,
            focalLength: focalLength,
            focalLenIn35mmFilm: focalLenIn35mm,
            showFNumber: !fNumber.isEmpty,
            fNumber: fNumber,
            showExposureTime: !exposureTime.isEmpty,
            exposureTime: exposureTime,
            showPhotographicSensitivity: !iso.isEmpty,
            photographicSensitivity: iso,
            showFlash: !flash.isEmpty,
            flash: flash,
            showSoftware: !software.isEmpty,
            software: software,
            showFilm: !film.isEmpty,
            film: film,
            showChemistry: !chemistry.isEmpty,
            chemistry: chemistry,
            showScanner: !scanner.isEmpty,
            scanner: scanner
        )
    }

    static func local(image: UIImage, imageData: Data?, parsedExif: ComposeParsedExif) -> ComposeStatusAttachment {
        return ComposeStatusAttachment(
            id: UUID(),
            serverId: nil,
            remoteImageURL: nil,
            localImage: image,
            originalImageData: imageData,
            blurhash: nil,
            isExistingAttachment: false,
            isUploading: false,
            uploadErrorMessage: nil,
            altText: parsedExif.description?.nilIfEmpty ?? "",
            licenseId: nil,
            countryCode: nil,
            countryName: nil,
            cityName: "",
            locationId: nil,
            showGpsCoordinates: false,
            latitude: parsedExif.latitude?.nilIfEmpty ?? "",
            longitude: parsedExif.longitude?.nilIfEmpty ?? "",
            showMake: parsedExif.make?.nilIfEmpty != nil,
            make: parsedExif.make?.nilIfEmpty ?? "",
            showModel: parsedExif.model?.nilIfEmpty != nil,
            model: parsedExif.model?.nilIfEmpty ?? "",
            showLens: parsedExif.lens?.nilIfEmpty != nil,
            lens: parsedExif.lens?.nilIfEmpty ?? "",
            showCreateDate: parsedExif.createDate?.nilIfEmpty != nil,
            createDate: parsedExif.createDate?.nilIfEmpty ?? "",
            showFocalLenIn35mmFilm: parsedExif.focalLength?.nilIfEmpty != nil || parsedExif.focalLenIn35mmFilm?.nilIfEmpty != nil,
            focalLength: parsedExif.focalLength?.nilIfEmpty ?? "",
            focalLenIn35mmFilm: parsedExif.focalLenIn35mmFilm?.nilIfEmpty ?? "",
            showFNumber: parsedExif.fNumber?.nilIfEmpty != nil,
            fNumber: parsedExif.fNumber?.nilIfEmpty ?? "",
            showExposureTime: parsedExif.exposureTime?.nilIfEmpty != nil,
            exposureTime: parsedExif.exposureTime?.nilIfEmpty ?? "",
            showPhotographicSensitivity: parsedExif.photographicSensitivity?.nilIfEmpty != nil,
            photographicSensitivity: parsedExif.photographicSensitivity?.nilIfEmpty ?? "",
            showFlash: parsedExif.flash?.nilIfEmpty != nil,
            flash: parsedExif.flash?.nilIfEmpty ?? "",
            showSoftware: parsedExif.software?.nilIfEmpty != nil,
            software: parsedExif.software?.nilIfEmpty ?? "",
            showFilm: false,
            film: "",
            showChemistry: false,
            chemistry: "",
            showScanner: false,
            scanner: ""
        )
    }

    func attachmentUpdateRequest() -> AttachmentUpdateRequest? {
        guard let serverId = serverId?.nilIfEmpty else {
            return nil
        }

        let normalizedFNumber = fNumber.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let fNumberLabel = normalizedFNumber.map { "f/\($0)" }

        return AttachmentUpdateRequest(
            id: serverId,
            description: altText.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            blurhash: blurhash?.nilIfEmpty,
            make: showMake ? make.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty : nil,
            model: showModel ? model.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty : nil,
            lens: showLens ? lens.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty : nil,
            createDate: showCreateDate ? createDate.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty : nil,
            focalLength: showFocalLenIn35mmFilm ? focalLength.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty : nil,
            focalLenIn35mmFilm: showFocalLenIn35mmFilm ? focalLenIn35mmFilm.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty : nil,
            fNumber: showFNumber ? fNumberLabel : nil,
            exposureTime: showExposureTime ? exposureTime.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty : nil,
            photographicSensitivity: showPhotographicSensitivity ? photographicSensitivity.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty : nil,
            software: showSoftware ? software.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty : nil,
            film: showFilm ? film.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty : nil,
            chemistry: showChemistry ? chemistry.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty : nil,
            scanner: showScanner ? scanner.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty : nil,
            locationId: locationId?.nilIfEmpty,
            licenseId: licenseId?.nilIfEmpty,
            latitude: showGpsCoordinates ? latitude.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty : nil,
            longitude: showGpsCoordinates ? longitude.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty : nil,
            flash: showFlash ? flash.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty : nil
        )
    }
}
