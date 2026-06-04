//
//  BroadcastFrameEncoder.swift
//  Shared between main app and ScreenRecorderExtension
//

import CoreImage
import CoreVideo

public struct BroadcastEncodeSize: Equatable, Sendable {
    public let width: Int
    public let height: Int
}

/// Normalizes ReplayKit pixel buffers to a stable encode size (≤720 long edge, even dims).
///
/// When a wired external display is connected, ReplayKit delivers frames with different
/// dimensions mid-session. Scaling every frame to the same locked size means the
/// AVAssetWriterInput never receives an incompatible buffer.
public final class BroadcastFrameEncoder: @unchecked Sendable {

    public static let maxLongEdge = 720

    private var _lockedSize: BroadcastEncodeSize?
    private var lastSourceWidth = 0
    private var lastSourceHeight = 0

    private let ciContext = CIContext()

    public init() {}

    // MARK: - Size Lock

    /// Returns (and caches) the encode size derived from the first seen source dimensions.
    public func lockedEncodeSize(sourceWidth: Int, sourceHeight: Int) -> BroadcastEncodeSize {
        if let s = _lockedSize { return s }

        lastSourceWidth = sourceWidth
        lastSourceHeight = sourceHeight

        let w = Self.evenDim(sourceWidth)
        let h = Self.evenDim(sourceHeight)
        let longEdge = max(w, h)
        let ratio = longEdge > Self.maxLongEdge ? Double(Self.maxLongEdge) / Double(longEdge) : 1.0
        let locked = BroadcastEncodeSize(
            width: Self.evenDim(Int((Double(w) * ratio).rounded(.down))),
            height: Self.evenDim(Int((Double(h) * ratio).rounded(.down)))
        )
        _lockedSize = locked
        return locked
    }

    /// Returns `true` if the source dimensions differ from when the size was first locked.
    /// Useful for logging wired-display topology changes.
    public func sourceDimensionsChanged(sourceWidth: Int, sourceHeight: Int) -> Bool {
        guard _lockedSize != nil else { return false }
        let changed = sourceWidth != lastSourceWidth || sourceHeight != lastSourceHeight
        if changed {
            lastSourceWidth = sourceWidth
            lastSourceHeight = sourceHeight
        }
        return changed
    }

    // MARK: - Scaling

    /// Scales `pixelBuffer` to `size`.
    /// - If the buffer already matches `size`, returns it as-is (no copy).
    /// - Tries to allocate the output buffer from `pool` first (adaptor pool); falls back to a new allocation.
    public func scale(
        pixelBuffer: CVPixelBuffer,
        to size: BroadcastEncodeSize,
        pool: CVPixelBufferPool? = nil
    ) -> CVPixelBuffer? {
        let srcW = CVPixelBufferGetWidth(pixelBuffer)
        let srcH = CVPixelBufferGetHeight(pixelBuffer)
        if srcW == size.width && srcH == size.height { return pixelBuffer }

        var outputBuffer: CVPixelBuffer?
        if let pool {
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &outputBuffer)
        }
        if outputBuffer == nil {
            let attrs = [kCVPixelBufferIOSurfacePropertiesKey: NSDictionary()] as CFDictionary
            CVPixelBufferCreate(
                kCFAllocatorDefault,
                size.width, size.height,
                kCVPixelFormatType_32BGRA,
                attrs,
                &outputBuffer
            )
        }
        guard let outputBuffer else { return nil }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let scaleX = CGFloat(size.width) / CGFloat(srcW)
        let scaleY = CGFloat(size.height) / CGFloat(srcH)
        let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        let outputBounds = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        ciContext.render(scaledImage, to: outputBuffer, bounds: outputBounds, colorSpace: nil)
        return outputBuffer
    }

    // MARK: - Helpers

    private static func evenDim(_ v: Int) -> Int {
        let clamped = max(2, v)
        return clamped % 2 == 0 ? clamped : clamped - 1
    }
}
