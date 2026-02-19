//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI

extension UIColor {
    var tonedPhotoBackdropColor: UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        guard getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            var white: CGFloat = 0
            getWhite(&white, alpha: &alpha)
            return UIColor(white: max(min(white * 0.32, 0.32), 0.1), alpha: 1)
        }
        
        return UIColor(
            hue: hue,
            saturation: min(max(saturation * 0.72, 0.18), 0.85),
            brightness: min(max(brightness * 0.36, 0.12), 0.34),
            alpha: 1
        )
    }
}
