//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import SwiftUI
import UIKit

struct ZoomableAttachmentScrollView: UIViewRepresentable {
    let imageURLString: String?
    let blurHash: String?
    let onZoomStateChanged: (Bool) -> Void
    let onDominantColorChanged: (UIColor) -> Void

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .clear
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.zoomScale = 1
        scrollView.bouncesZoom = true
        scrollView.alwaysBounceVertical = false
        scrollView.alwaysBounceHorizontal = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.decelerationRate = .normal
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.bounces = true

        context.coordinator.attachImageView(to: scrollView)
        context.coordinator.updateContent(imageURLString: imageURLString, blurHash: blurHash)

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updateContent(imageURLString: imageURLString, blurHash: blurHash)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: ZoomableAttachmentScrollView

        private weak var scrollView: UIScrollView?
        private weak var imageView: UIImageView?
        private var imageTask: URLSessionDataTask?
        private var loadedURLString: String?
        private var zoomState: Bool = false
        private var lastLayoutBoundsSize: CGSize = .zero

        init(parent: ZoomableAttachmentScrollView) {
            self.parent = parent
        }

        deinit {
            imageTask?.cancel()
        }

        func attachImageView(to scrollView: UIScrollView) {
            guard imageView == nil else {
                self.scrollView = scrollView
                relayoutImageIfNeeded(in: scrollView, preserveZoomScale: true)
                return
            }

            let imageView = UIImageView()
            imageView.frame = scrollView.bounds
            imageView.contentMode = .scaleToFill
            imageView.clipsToBounds = true
            imageView.isUserInteractionEnabled = true

            scrollView.addSubview(imageView)

            self.scrollView = scrollView
            self.imageView = imageView
            relayoutImageIfNeeded(in: scrollView, preserveZoomScale: true)
        }

        func updateContent(imageURLString: String?, blurHash: String?) {
            guard let imageView, let scrollView else {
                return
            }

            if lastLayoutBoundsSize != scrollView.bounds.size {
                relayoutImageIfNeeded(in: scrollView, preserveZoomScale: true)
            }

            if loadedURLString == imageURLString {
                return
            }

            imageTask?.cancel()
            loadedURLString = imageURLString

            scrollView.minimumZoomScale = 1
            scrollView.maximumZoomScale = 4
            scrollView.setZoomScale(1, animated: false)
            notifyZoomStateIfNeeded(false)

            if let blurHash = blurHash?.nilIfEmpty,
               let placeholder = UIImage(blurHash: blurHash, size: CGSize(width: 64, height: 64), punch: 1) {
                imageView.image = placeholder
                notifyDominantColorIfPossible(from: placeholder)
            } else {
                imageView.image = nil
                parent.onDominantColorChanged(.black)
            }
            relayoutImageIfNeeded(in: scrollView, preserveZoomScale: false)

            guard let imageURLString = imageURLString?.nilIfEmpty,
                  let url = URL(string: imageURLString) else {
                return
            }

            imageTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let self, let data, let image = UIImage(data: data) else {
                    return
                }

                DispatchQueue.main.async {
                    guard self.loadedURLString == imageURLString else {
                        return
                    }

                    UIView.transition(with: imageView, duration: 0.2, options: .transitionCrossDissolve) {
                        imageView.image = image
                    }
                    self.notifyDominantColorIfPossible(from: image)
                    self.relayoutImageIfNeeded(in: scrollView, preserveZoomScale: true)
                }
            }
            imageTask?.resume()
        }

        @objc
        func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView, let imageView else {
                return
            }

            if scrollView.zoomScale > scrollView.minimumZoomScale + 0.01 {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
                notifyZoomStateIfNeeded(false)
                return
            }

            let targetScale = min(scrollView.maximumZoomScale, 2.4)
            let tapPoint = recognizer.location(in: imageView)
            let zoomRect = zoomRect(for: targetScale, center: tapPoint, in: scrollView)
            scrollView.zoom(to: zoomRect, animated: true)
            notifyZoomStateIfNeeded(true)
        }

        private func zoomRect(for scale: CGFloat, center: CGPoint, in scrollView: UIScrollView) -> CGRect {
            let size = scrollView.bounds.size
            let width = size.width / scale
            let height = size.height / scale
            return CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
        }

        private func notifyZoomStateIfNeeded(_ isZoomed: Bool) {
            guard zoomState != isZoomed else {
                return
            }

            zoomState = isZoomed
            parent.onZoomStateChanged(isZoomed)
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            updateInsetsToKeepImageCentered(in: scrollView)
            notifyZoomStateIfNeeded(scrollView.zoomScale > scrollView.minimumZoomScale + 0.01)
        }

        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            snapContentOffsetToBounds(in: scrollView, animated: true)
            notifyZoomStateIfNeeded(scale > scrollView.minimumZoomScale + 0.01)
        }
        
        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            guard !decelerate else {
                return
            }
            
            snapContentOffsetToBounds(in: scrollView, animated: true)
        }
        
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            snapContentOffsetToBounds(in: scrollView, animated: true)
        }
        
        private func relayoutImageIfNeeded(in scrollView: UIScrollView, preserveZoomScale: Bool) {
            guard let imageView else {
                return
            }
            
            let boundsSize = scrollView.bounds.size
            guard boundsSize.width > 0, boundsSize.height > 0 else {
                return
            }
            
            let previousZoomScale = scrollView.zoomScale
            let hasValidImageSize: Bool
            let fittedSize: CGSize
            
            if let image = imageView.image, image.size.width > 0, image.size.height > 0 {
                hasValidImageSize = true
                let widthScale = boundsSize.width / image.size.width
                let heightScale = boundsSize.height / image.size.height
                let fitScale = min(widthScale, heightScale)
                fittedSize = CGSize(width: image.size.width * fitScale, height: image.size.height * fitScale)
            } else {
                hasValidImageSize = false
                fittedSize = boundsSize
            }
            
            imageView.frame = CGRect(origin: .zero, size: fittedSize)
            scrollView.contentSize = fittedSize
            updateInsetsToKeepImageCentered(in: scrollView)
            
            if !preserveZoomScale || !hasValidImageSize {
                scrollView.zoomScale = scrollView.minimumZoomScale
            } else {
                let minScale = scrollView.minimumZoomScale
                let maxScale = scrollView.maximumZoomScale
                scrollView.zoomScale = min(max(previousZoomScale, minScale), maxScale)
            }
            
            lastLayoutBoundsSize = boundsSize
            snapContentOffsetToBounds(in: scrollView, animated: false)
        }
        
        private func updateInsetsToKeepImageCentered(in scrollView: UIScrollView) {
            let horizontalInset = max((scrollView.bounds.width - scrollView.contentSize.width) / 2, 0)
            let verticalInset = max((scrollView.bounds.height - scrollView.contentSize.height) / 2, 0)
            scrollView.contentInset = UIEdgeInsets(top: verticalInset,
                                                   left: horizontalInset,
                                                   bottom: verticalInset,
                                                   right: horizontalInset)
        }
        
        private func snapContentOffsetToBounds(in scrollView: UIScrollView, animated: Bool) {
            let minOffsetX = -scrollView.contentInset.left
            let maxOffsetX = max(minOffsetX, scrollView.contentSize.width - scrollView.bounds.width + scrollView.contentInset.right)
            let minOffsetY = -scrollView.contentInset.top
            let maxOffsetY = max(minOffsetY, scrollView.contentSize.height - scrollView.bounds.height + scrollView.contentInset.bottom)
            
            var targetOffset = scrollView.contentOffset
            targetOffset.x = min(max(targetOffset.x, minOffsetX), maxOffsetX)
            targetOffset.y = min(max(targetOffset.y, minOffsetY), maxOffsetY)
            
            guard abs(targetOffset.x - scrollView.contentOffset.x) > 0.5 ||
                  abs(targetOffset.y - scrollView.contentOffset.y) > 0.5 else {
                return
            }
            
            if animated {
                UIView.animate(withDuration: 0.24,
                               delay: 0,
                               usingSpringWithDamping: 0.88,
                               initialSpringVelocity: 0.18,
                               options: [.allowUserInteraction, .beginFromCurrentState]) {
                    scrollView.contentOffset = targetOffset
                }
            } else {
                scrollView.contentOffset = targetOffset
            }
        }
        
        private func notifyDominantColorIfPossible(from image: UIImage) {
            guard let dominantColor = image.averageColor else {
                return
            }
            
            parent.onDominantColorChanged(dominantColor)
        }
    }
}
