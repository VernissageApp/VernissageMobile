//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

enum ComposeParsedExifParser {
    static func parse(from data: Data) -> ComposeParsedExif {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return ComposeParsedExif()
        }

        return parse(properties: properties)
    }

    static func parse(from url: URL) -> ComposeParsedExif {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return ComposeParsedExif()
        }

        return parse(properties: properties)
    }

    private static func parse(properties: [CFString: Any]) -> ComposeParsedExif {
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any]
        let iptc = properties[kCGImagePropertyIPTCDictionary] as? [CFString: Any]

        var result = ComposeParsedExif()
        result.description = stringValue(iptc?[kCGImagePropertyIPTCCaptionAbstract])
        result.make = stringValue(tiff?[kCGImagePropertyTIFFMake])
        result.model = stripManufacturerFromModel(
            model: stringValue(tiff?[kCGImagePropertyTIFFModel]),
            manufacturer: result.make
        )
        result.lens = stringValue(exif?[kCGImagePropertyExifLensModel])
        result.createDate = stringValue(exif?[kCGImagePropertyExifDateTimeOriginal]) ?? stringValue(exif?[kCGImagePropertyExifDateTimeDigitized])
        result.focalLength = numberLabel(exif?[kCGImagePropertyExifFocalLength])
        result.focalLenIn35mmFilm = numberLabel(exif?[kCGImagePropertyExifFocalLenIn35mmFilm])
        result.fNumber = numberLabel(exif?[kCGImagePropertyExifFNumber])
        result.exposureTime = numberLabel(exif?[kCGImagePropertyExifExposureTime])
        result.photographicSensitivity = isoValue(exif?[kCGImagePropertyExifISOSpeedRatings])
        result.software = stringValue(tiff?[kCGImagePropertyTIFFSoftware])
        result.flash = stringValue(exif?[kCGImagePropertyExifFlash])

        if let (latitude, longitude) = gpsCoordinates(from: gps) {
            result.latitude = latitude
            result.longitude = longitude
        }

        return result
    }

    private static func stripManufacturerFromModel(model: String?, manufacturer: String?) -> String? {
        guard var model = model?.nilIfEmpty else {
            return nil
        }

        if let manufacturer = manufacturer?.nilIfEmpty,
           model.lowercased().hasPrefix(manufacturer.lowercased()) {
            model = String(model.dropFirst(manufacturer.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return model.nilIfEmpty
    }

    private static func gpsCoordinates(from gps: [CFString: Any]?) -> (String, String)? {
        guard let gps else {
            return nil
        }

        guard var latitude = doubleValue(gps[kCGImagePropertyGPSLatitude]),
              var longitude = doubleValue(gps[kCGImagePropertyGPSLongitude]) else {
            return nil
        }

        let latitudeRef = stringValue(gps[kCGImagePropertyGPSLatitudeRef])?.uppercased()
        let longitudeRef = stringValue(gps[kCGImagePropertyGPSLongitudeRef])?.uppercased()

        if latitudeRef == "S" {
            latitude *= -1
        }

        if longitudeRef == "W" {
            longitude *= -1
        }

        return (coordinateLabel(latitude), coordinateLabel(longitude))
    }

    private static func coordinateLabel(_ value: Double) -> String {
        value.formatted(
            .number
                .locale(Locale(identifier: "en_US_POSIX"))
                .precision(.fractionLength(0...6))
        )
    }

    private static func isoValue(_ value: Any?) -> String? {
        if let values = value as? [Any], let first = values.first {
            return numberLabel(first)
        }

        return numberLabel(value)
    }

    private static func numberLabel(_ value: Any?) -> String? {
        if let number = value as? NSNumber {
            return number.stringValue
        }

        if let double = value as? Double {
            if floor(double) == double {
                return String(Int(double))
            }

            return String(double)
        }

        if let int = value as? Int {
            return String(int)
        }

        if let string = value as? String {
            return string.nilIfEmpty
        }

        return nil
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }

        if let double = value as? Double {
            return double
        }

        if let string = value as? String {
            return Double(string)
        }

        return nil
    }

    private static func stringValue(_ value: Any?) -> String? {
        if let string = value as? String {
            return string.nilIfEmpty
        }

        if let number = value as? NSNumber {
            return number.stringValue.nilIfEmpty
        }

        return nil
    }
}
