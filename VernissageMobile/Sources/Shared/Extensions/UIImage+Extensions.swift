//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI
import CoreImage

extension UIImage {
    var averageColor: UIColor? {
        guard let cgImage else {
            return nil
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        let extent = ciImage.extent
        guard !extent.isEmpty else {
            return nil
        }
        
        guard let filter = CIFilter(name: "CIAreaAverage") else {
            return nil
        }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: extent), forKey: kCIInputExtentKey)
        
        guard let outputImage = filter.outputImage else {
            return nil
        }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        context.render(outputImage,
                       toBitmap: &bitmap,
                       rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8,
                       colorSpace: CGColorSpaceCreateDeviceRGB())
        
        return UIColor(red: CGFloat(bitmap[0]) / 255,
                       green: CGFloat(bitmap[1]) / 255,
                       blue: CGFloat(bitmap[2]) / 255,
                       alpha: 1)
    }
}
public extension UIImage {

    /// Code downloaded from: https://github.com/woltapp/blurhash/tree/master/Swift
    convenience init?(blurHash: String, size: CGSize, punch: Float = 1) {
        guard blurHash.count >= 6 else { return nil }

        let sizeFlag = String(blurHash[0]).decode83()
        let numY = (sizeFlag / 9) + 1
        let numX = (sizeFlag % 9) + 1

        let quantisedMaximumValue = String(blurHash[1]).decode83()
        let maximumValue = Float(quantisedMaximumValue + 1) / 166

        guard blurHash.count == 4 + 2 * numX * numY else { return nil }

        let colours: [(Float, Float, Float)] = (0 ..< numX * numY).map { index in
            if index == 0 {
                let value = String(blurHash[2 ..< 6]).decode83()
                return decodeDC(value)
            } else {
                let value = String(blurHash[4 + index * 2 ..< 4 + index * 2 + 2]).decode83()
                return decodeAC(value, maximumValue: maximumValue * punch)
            }
        }

        let width = Int(size.width)
        let height = Int(size.height)
        let bytesPerRow = width * 3
        guard let data = CFDataCreateMutable(kCFAllocatorDefault, bytesPerRow * height) else { return nil }
        CFDataSetLength(data, bytesPerRow * height)
        guard let pixels = CFDataGetMutableBytePtr(data) else { return nil }

        for yPoint in 0 ..< height {
            for xPoint in 0 ..< width {
                var red: Float = 0
                var green: Float = 0
                var blue: Float = 0

                for jIndex in 0 ..< numY {
                    for iIndex in 0 ..< numX {
                        let basis = cos(Float.pi * Float(xPoint) * Float(iIndex) / Float(width)) * cos(Float.pi * Float(yPoint) * Float(jIndex) / Float(height))
                        let colour = colours[iIndex + jIndex * numX]
                        red += colour.0 * basis
                        green += colour.1 * basis
                        blue += colour.2 * basis
                    }
                }

                let intR = UInt8(linearTosRGB(red))
                let intG = UInt8(linearTosRGB(green))
                let intB = UInt8(linearTosRGB(blue))

                pixels[3 * xPoint + 0 + yPoint * bytesPerRow] = intR
                pixels[3 * xPoint + 1 + yPoint * bytesPerRow] = intG
                pixels[3 * xPoint + 2 + yPoint * bytesPerRow] = intB
            }
        }

        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)

        guard let provider = CGDataProvider(data: data) else { return nil }
        guard let cgImage = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 24, bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo, provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { return nil }

        self.init(cgImage: cgImage)
    }

    /// Code downloaded from: https://github.com/woltapp/blurhash/tree/master/Swift
    func blurHash(numberOfComponents components: (Int, Int) = (4, 3), maxLongestEdge: CGFloat = 180) -> String? {
        let imageForHash: UIImage
        if maxLongestEdge > 0 {
            imageForHash = self.resizedForBlurHash(maxLongestEdge: maxLongestEdge)
        } else {
            imageForHash = self
        }

        guard let cgImage = imageForHash.cgImage else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else {
            return nil
        }

        let numX = min(max(components.0, 1), 9)
        let numY = min(max(components.1, 1), 9)

        let bitsPerComponent = 8
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var factors: [(Float, Float, Float)] = []
        factors.reserveCapacity(numX * numY)

        for yComponent in 0..<numY {
            for xComponent in 0..<numX {
                let normalisation: Float = (xComponent == 0 && yComponent == 0) ? 1 : 2
                var red: Float = 0
                var green: Float = 0
                var blue: Float = 0

                for y in 0..<height {
                    for x in 0..<width {
                        let basis = cos(Float.pi * Float(xComponent) * Float(x) / Float(width)) *
                            cos(Float.pi * Float(yComponent) * Float(y) / Float(height))
                        let index = 4 * x + y * bytesPerRow

                        red += basis * sRGBToLinear(pixelData[index])
                        green += basis * sRGBToLinear(pixelData[index + 1])
                        blue += basis * sRGBToLinear(pixelData[index + 2])
                    }
                }

                let scale = normalisation / Float(width * height)
                factors.append((red * scale, green * scale, blue * scale))
            }
        }

        let dc = factors[0]
        let ac = Array(factors.dropFirst())
        let maximumValue: Float
        let quantisedMaximumValue: Int

        if ac.isEmpty {
            maximumValue = 1
            quantisedMaximumValue = 0
        } else {
            var maxAC: Float = 0
            for factor in ac {
                maxAC = max(maxAC, abs(factor.0), abs(factor.1), abs(factor.2))
            }

            quantisedMaximumValue = Int(max(0, min(82, floor(maxAC * 166 - 0.5))))
            maximumValue = Float(quantisedMaximumValue + 1) / 166
        }

        var blurHash = ""
        blurHash += encode83((numX - 1) + (numY - 1) * 9, length: 1)
        blurHash += encode83(quantisedMaximumValue, length: 1)
        blurHash += encode83(encodeDC(dc), length: 4)

        for factor in ac {
            blurHash += encode83(encodeAC(factor, maximumValue: maximumValue), length: 2)
        }

        return blurHash
    }

    func convertToExtendedSRGBJpeg() -> Data? {
        guard let sourceImage = CIImage(image: self, options: [.applyOrientationProperty: true]) else {
            return self.jpegData(compressionQuality: 0.9)
        }

        let orientedImage = sourceImage.oriented(forExifOrientation: self.imageOrientation.exifOrientation)

        let sRGBName = CGColorSpace(name: CGColorSpace.sRGB)?.name
        let extendedSRGBName = CGColorSpace(name: CGColorSpace.extendedSRGB)?.name
        if orientedImage.colorSpace?.name == sRGBName || orientedImage.colorSpace?.name == extendedSRGBName {
            return self.jpegData(compressionQuality: 0.9)
        }

        guard let colorSpace = CGColorSpace(name: CGColorSpace.extendedSRGB) else {
            return self.jpegData(compressionQuality: 0.9)
        }

        guard let displayP3 = CGColorSpace(name: CGColorSpace.displayP3) else {
            return self.jpegData(compressionQuality: 0.9)
        }

        let ciContext = CIContext(options: [
            CIContextOption.workingColorSpace: orientedImage.colorSpace ?? displayP3
        ])

        let representationOptions: [CIImageRepresentationOption: Any] = [
            kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.9
        ]

        guard let converted = ciContext.jpegRepresentation(
            of: orientedImage,
            colorSpace: colorSpace,
            options: representationOptions
        ) else {
            return self.jpegData(compressionQuality: 0.9)
        }

        return converted
    }

    private func resizedForBlurHash(maxLongestEdge: CGFloat) -> UIImage {
        guard maxLongestEdge > 0 else {
            return self
        }

        let originalSize = self.size
        let longestEdge = max(originalSize.width, originalSize.height)
        guard longestEdge > maxLongestEdge, longestEdge > 0 else {
            return self
        }

        let scale = maxLongestEdge / longestEdge
        let targetSize = CGSize(width: originalSize.width * scale, height: originalSize.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)

        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

private func decodeDC(_ value: Int) -> (Float, Float, Float) {
    let intR = value >> 16
    let intG = (value >> 8) & 255
    let intB = value & 255
    return (sRGBToLinear(intR), sRGBToLinear(intG), sRGBToLinear(intB))
}

private func decodeAC(_ value: Int, maximumValue: Float) -> (Float, Float, Float) {
    let quantR = value / (19 * 19)
    let quantG = (value / 19) % 19
    let quantB = value % 19

    return (
        signPow((Float(quantR) - 9) / 9, 2) * maximumValue,
        signPow((Float(quantG) - 9) / 9, 2) * maximumValue,
        signPow((Float(quantB) - 9) / 9, 2) * maximumValue
    )
}

private func encodeDC(_ value: (Float, Float, Float)) -> Int {
    let roundedR = linearTosRGB(value.0)
    let roundedG = linearTosRGB(value.1)
    let roundedB = linearTosRGB(value.2)

    return (roundedR << 16) + (roundedG << 8) + roundedB
}

private func encodeAC(_ value: (Float, Float, Float), maximumValue: Float) -> Int {
    guard maximumValue > 0 else {
        return 0
    }

    let quantR = Int(max(0, min(18, floor(signPow(value.0 / maximumValue, 0.5) * 9 + 9.5))))
    let quantG = Int(max(0, min(18, floor(signPow(value.1 / maximumValue, 0.5) * 9 + 9.5))))
    let quantB = Int(max(0, min(18, floor(signPow(value.2 / maximumValue, 0.5) * 9 + 9.5))))

    return quantR * 19 * 19 + quantG * 19 + quantB
}

private func encode83(_ value: Int, length: Int) -> String {
    var result = ""
    var divisor = 1

    if length > 1 {
        for _ in 1..<length {
            divisor *= 83
        }
    }

    var currentDivisor = divisor
    while currentDivisor > 0 {
        let digit = (value / currentDivisor) % 83
        result += blurHashEncodeCharacters[digit]
        currentDivisor /= 83
    }

    return result
}

private func signPow(_ value: Float, _ exp: Float) -> Float {
    copysign(pow(abs(value), exp), value)
}

private func linearTosRGB(_ value: Float) -> Int {
    let maxV = max(0, min(1, value))
    if maxV <= 0.0031308 {
        return Int(maxV * 12.92 * 255 + 0.5)
    } else {
        return Int((1.055 * pow(maxV, 1 / 2.4) - 0.055) * 255 + 0.5)
    }
}

private func sRGBToLinear<Type: BinaryInteger>(_ value: Type) -> Float {
    let floatV = Float(Int64(value)) / 255
    if floatV <= 0.04045 {
        return floatV / 12.92
    } else {
        return pow((floatV + 0.055) / 1.055, 2.4)
    }
}

private let blurHashEncodeCharacters: [String] = {
    "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz#$%*+,-.:;=?@[]^_{|}~".map { String($0) }
}()

private extension UIImage.Orientation {
    var exifOrientation: Int32 {
        switch self {
        case .up:
            return 1
        case .upMirrored:
            return 2
        case .down:
            return 3
        case .downMirrored:
            return 4
        case .leftMirrored:
            return 5
        case .right:
            return 6
        case .rightMirrored:
            return 7
        case .left:
            return 8
        @unknown default:
            return 1
        }
    }
}
