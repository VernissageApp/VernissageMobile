//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

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
