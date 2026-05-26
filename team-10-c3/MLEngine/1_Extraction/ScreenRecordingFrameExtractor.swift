import AVFoundation
import CoreMedia
import CoreVideo

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
    
    public init(index: Int, timestamp: TimeInterval, pixelBuffer: CVPixelBuffer) {
        self.index = index
        self.timestamp = timestamp
        self.pixelBuffer = pixelBuffer
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
        while reader.status == .reading {
            guard let sampleBuffer = output.copyNextSampleBuffer(),
                  let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                continue
            }

            let timestamp = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            
            // We only yield the frame if it matches our 3-second interval rule
            if shouldClassify(at: timestamp) {
                try await body(
                    ScreenRecordingFrame(
                        index: index,
                        timestamp: timestamp,
                        pixelBuffer: pixelBuffer
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
}