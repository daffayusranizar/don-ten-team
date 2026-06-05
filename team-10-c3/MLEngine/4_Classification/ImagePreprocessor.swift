import CoreImage
import CoreVideo
import UIKit

struct ModelInputPreviews {
    let fullFrame: UIImage?
    let bottomCrop: UIImage?
}

/// UI-sized captures from a sampled recording frame (for timeline / screen breakdown).
struct FrameDisplayImages {
    let thumbnail: UIImage?
    let bottomCropThumbnail: UIImage?
}

enum ImagePreprocessor {
    private static let modelInputSize = 256
    private static let screenshotAspectThreshold: CGFloat = 1.6
    // Using a nonisolated CIContext so it can be safely called from any actor
    private static let renderContext = CIContext(options: [.useSoftwareRenderer: false])

    nonisolated(unsafe)
    static func modelInputBuffers(
        from image: UIImage,
        size: Int = modelInputSize
    ) -> [CVPixelBuffer]? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let oriented = ciImage.oriented(forExifOrientation: image.imageOrientation.exifOrientation)
        return modelInputBuffers(from: oriented, size: size)
    }

    nonisolated(unsafe)
    static func modelInputBuffers(
        from source: CVPixelBuffer,
        size: Int = modelInputSize
    ) -> [CVPixelBuffer]? {
        modelInputBuffers(from: CIImage(cvPixelBuffer: source), size: size)
    }

    nonisolated(unsafe)
    static func modelInputPreviews(
        from source: CVPixelBuffer,
        size: Int = modelInputSize
    ) -> ModelInputPreviews {
        let buffers = modelInputBuffers(from: source, size: size) ?? []
        let images = buffers.compactMap { uiImage(from: $0) }
        return ModelInputPreviews(fullFrame: images.first, bottomCrop: nil)
    }

    nonisolated(unsafe) static func uiImage(from pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = renderContext.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    /// Full-frame screenshot for timeline / screen breakdown.
    nonisolated(unsafe) static func frameDisplayImages(from source: CVPixelBuffer) -> FrameDisplayImages {
        let thumbnail = uiImage(from: source)
        return FrameDisplayImages(thumbnail: thumbnail, bottomCropThumbnail: nil)
    }

    /// Left-bottom overlay zone for TikTok/Reels handle OCR at native resolution.
    nonisolated(unsafe) static func overlayCrop(from source: CVPixelBuffer) -> CVPixelBuffer? {
        let ciImage = CIImage(cvPixelBuffer: source)
        let cropped = overlayCrop(from: ciImage)
        let extent = cropped.extent.integral
        guard extent.width >= 32, extent.height >= 32 else { return nil }
        return pixelBuffer(
            from: cropped,
            width: Int(extent.width.rounded(.down)),
            height: Int(extent.height.rounded(.down))
        )
    }

    nonisolated(unsafe) static func overlayCrop(from image: CIImage) -> CIImage {
        let extent = image.extent.integral
        guard extent.width > 0, extent.height > 0 else { return image }

        let aspect = extent.height / extent.width
        let cropWidth = aspect >= screenshotAspectThreshold ? extent.width * 0.65 : extent.width
        let cropHeight = extent.height * 0.40
        let cropRect = CGRect(
            x: extent.minX,
            y: extent.minY,
            width: cropWidth,
            height: cropHeight
        )
        return image.cropped(to: cropRect)
    }

    private static func modelInputBuffers(from image: CIImage, size: Int) -> [CVPixelBuffer]? {
        let extent = image.extent.integral
        guard extent.width > 0, extent.height > 0 else { return nil }

        guard let fullFrame = pixelBuffer(
            from: letterbox(image, targetSize: CGFloat(size)),
            width: size,
            height: size
        ) else {
            return nil
        }
        return [fullFrame]
    }

    private static func isTallScreenshot(_ source: CVPixelBuffer) -> Bool {
        let width = CVPixelBufferGetWidth(source)
        let height = CVPixelBufferGetHeight(source)
        guard width > 0 else { return false }
        return CGFloat(height) / CGFloat(width) >= screenshotAspectThreshold
    }

    private static func letterbox(_ image: CIImage, targetSize: CGFloat) -> CIImage {
        let extent = image.extent.integral
        guard extent.width > 0, extent.height > 0 else { return image }

        let scale = min(targetSize / extent.width, targetSize / extent.height)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let scaledExtent = scaled.extent

        let offsetX = (targetSize - scaledExtent.width) / 2 - scaledExtent.origin.x
        let offsetY = (targetSize - scaledExtent.height) / 2 - scaledExtent.origin.y
        let positioned = scaled.transformed(by: CGAffineTransform(translationX: offsetX, y: offsetY))

        let background = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 1))
            .cropped(to: CGRect(x: 0, y: 0, width: targetSize, height: targetSize))

        return positioned.composited(over: background)
    }

    private static func pixelBuffer(from image: CIImage, width: Int, height: Int) -> CVPixelBuffer? {
        var output: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &output
        )

        guard status == kCVReturnSuccess, let buffer = output else { return nil }
        renderContext.render(image, to: buffer)
        return buffer
    }
}

private extension UIImage.Orientation {
    var exifOrientation: Int32 {
        switch self {
        case .up: 1
        case .down: 3
        case .left: 8
        case .right: 6
        case .upMirrored: 2
        case .downMirrored: 4
        case .leftMirrored: 5
        case .rightMirrored: 7
        @unknown default: 1
        }
    }
}
