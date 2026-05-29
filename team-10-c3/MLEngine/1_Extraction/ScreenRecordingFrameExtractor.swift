import AVFoundation
import CoreMedia
import CoreVideo
import VideoToolbox

public struct ScreenRecordingMetadata: Sendable {
    public let fps: Float
    public let duration: TimeInterval
    public let estimatedFrameCount: Int
    
    public init(fps: Float, duration: TimeInterval, estimatedFrameCount: Int) {
        self.fps = fps
        self.duration = duration
        self.estimatedFrameCount = estimatedFrameCount
    }
}

public struct ScreenRecordingFrame: Sendable {
    public let index: Int
    public let timestamp: TimeInterval
    public let pixelBuffer: CVPixelBuffer
    public let isDuplicateOfPrevious: Bool
    
    public init(index: Int, timestamp: TimeInterval, pixelBuffer: CVPixelBuffer, isDuplicateOfPrevious: Bool = false) {
        self.index = index
        self.timestamp = timestamp
        self.pixelBuffer = pixelBuffer
        self.isDuplicateOfPrevious = isDuplicateOfPrevious
    }
}

public actor ScreenRecordingFrameExtractor {
    public enum ExtractionError: LocalizedError {
        case unreadableVideo
        case noFrames

        public var errorDescription: String? {
            switch self {
            case .unreadableVideo:
                return "Could not read the saved screen recording."
            case .noFrames:
                return "The screen recording did not contain any frames to analyze."
            }
        }
    }

    public init() {}

    public func loadMetadata(from videoURL: URL) async throws -> ScreenRecordingMetadata {
        let asset = AVURLAsset(url: videoURL)
        guard !(try await asset.loadTracks(withMediaType: .video)).isEmpty else {
            throw ExtractionError.unreadableVideo
        }

        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        guard durationSeconds.isFinite, durationSeconds > 0 else {
            throw ExtractionError.unreadableVideo
        }

        let fps: Float = 1.0
        let estimatedFrameCount = estimatedClassificationFrameCount(durationSeconds: durationSeconds)
        return ScreenRecordingMetadata(
            fps: fps,
            duration: durationSeconds,
            estimatedFrameCount: estimatedFrameCount
        )
    }

    public func estimatedClassificationFrameCount(durationSeconds: TimeInterval) -> Int {
        let interval = 3
        return max(1, Int(floor(durationSeconds / Double(interval))) + 1)
    }

    public func shouldClassify(at timestamp: TimeInterval) -> Bool {
        let interval = 3
        let second = Int(timestamp.rounded(.down))
        return second % interval == 0
    }

    public func forEachFrame(
        from videoURL: URL,
        body: @Sendable (ScreenRecordingFrame) async throws -> Void
    ) async throws -> Int {
        let asset = AVURLAsset(url: videoURL)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw ExtractionError.unreadableVideo
        }

        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            ]
        )
        output.alwaysCopiesSampleData = false
        reader.add(output)

        guard reader.startReading() else {
            throw reader.error ?? ExtractionError.unreadableVideo
        }

        var index = 0
        var previousBuffer: CVPixelBuffer?
        
        while reader.status == .reading {
            guard let sampleBuffer = output.copyNextSampleBuffer(),
                  let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                continue
            }

            let timestamp = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            
            // We only yield the frame if it matches our 3-second interval rule
            if shouldClassify(at: timestamp) {
                let resizedBuffer = downscale(pixelBuffer: pixelBuffer)
                
                let isDup = previousBuffer != nil ? isDuplicate(bufferA: previousBuffer!, bufferB: resizedBuffer) : false
                previousBuffer = resizedBuffer
                
                try await body(
                    ScreenRecordingFrame(
                        index: index,
                        timestamp: timestamp,
                        pixelBuffer: resizedBuffer,
                        isDuplicateOfPrevious: isDup
                    )
                )
            }
            index += 1
        }

        if reader.status == .failed {
            throw reader.error ?? ExtractionError.unreadableVideo
        }

        guard index > 0 else { throw ExtractionError.noFrames }
        return index
    }
    
    private func downscale(pixelBuffer: CVPixelBuffer) -> CVPixelBuffer {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        // If it's already small enough (e.g. 720p or less), don't resize it
        if width <= 720 { return pixelBuffer }
        
        let scale: Double = 720.0 / Double(width)
        let targetWidth = 720
        let targetHeight = Int(Double(height) * scale)
        
        var unmanagedSession: VTPixelTransferSession?
        VTPixelTransferSessionCreate(allocator: kCFAllocatorDefault, pixelTransferSessionOut: &unmanagedSession)
        guard let session = unmanagedSession else { return pixelBuffer }
        
        var outputBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ] as CFDictionary
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault, targetWidth, targetHeight, CVPixelBufferGetPixelFormatType(pixelBuffer), attrs, &outputBuffer)
        
        guard status == kCVReturnSuccess, let outBuffer = outputBuffer else { return pixelBuffer }
        VTPixelTransferSessionTransferImage(session, from: pixelBuffer, to: outBuffer)
        
        return outBuffer
    }
    
    private func isDuplicate(bufferA: CVPixelBuffer, bufferB: CVPixelBuffer) -> Bool {
        guard CVPixelBufferGetWidth(bufferA) == CVPixelBufferGetWidth(bufferB),
              CVPixelBufferGetHeight(bufferA) == CVPixelBufferGetHeight(bufferB) else {
            return false
        }
        
        CVPixelBufferLockBaseAddress(bufferA, .readOnly)
        CVPixelBufferLockBaseAddress(bufferB, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(bufferA, .readOnly)
            CVPixelBufferUnlockBaseAddress(bufferB, .readOnly)
        }
        
        guard let baseA = CVPixelBufferGetBaseAddress(bufferA)?.assumingMemoryBound(to: UInt8.self),
              let baseB = CVPixelBufferGetBaseAddress(bufferB)?.assumingMemoryBound(to: UInt8.self) else {
            return false
        }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(bufferA)
        let height = CVPixelBufferGetHeight(bufferA)
        let width = CVPixelBufferGetWidth(bufferA)
        
        var diffSum: Int = 0
        var samples = 0
        
        // Sample roughly 100 pixels across the screen
        let stepY = max(1, height / 10)
        let stepX = max(1, width / 10)
        
        for y in stride(from: 0, to: height, by: stepY) {
            for x in stride(from: 0, to: width, by: stepX) {
                let offset = y * bytesPerRow + x * 4
                let bA = Int(baseA[offset])
                let gA = Int(baseA[offset + 1])
                let rA = Int(baseA[offset + 2])
                
                let bB = Int(baseB[offset])
                let gB = Int(baseB[offset + 1])
                let rB = Int(baseB[offset + 2])
                
                let diff = abs(bA - bB) + abs(gA - gB) + abs(rA - rB)
                diffSum += diff
                samples += 1
            }
        }
        
        let avgDiff = samples > 0 ? (diffSum / samples) : 0
        // If average absolute difference across RGB channels is small, it's effectively identical
        return avgDiff < 15
    }
}