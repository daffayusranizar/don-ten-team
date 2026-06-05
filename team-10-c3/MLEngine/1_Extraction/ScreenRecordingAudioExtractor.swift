import AVFoundation
import Foundation

public struct ScreenRecordingAudioSegment: Sendable {
    public let timestamp: TimeInterval
    public let wavURL: URL

    public init(timestamp: TimeInterval, wavURL: URL) {
        self.timestamp = timestamp
        self.wavURL = wavURL
    }
}

public actor ScreenRecordingAudioExtractor {
    public enum ExtractionError: LocalizedError {
        case unreadableAudio
        case exportFailed

        public var errorDescription: String? {
            switch self {
            case .unreadableAudio:
                return "Could not read audio from the saved screen recording."
            case .exportFailed:
                return "Could not export an audio segment for transcription."
            }
        }
    }

    private let whisperSampleRate: Double = 16_000
    private let windowDuration: TimeInterval = 3.0

    public init() {}

    public func hasAudioTrack(in videoURL: URL) async -> Bool {
        let asset = AVURLAsset(url: videoURL)
        let tracks = (try? await asset.loadTracks(withMediaType: .audio)) ?? []
        return !tracks.isEmpty
    }

    public func exportFullAudio(from videoURL: URL) async throws -> URL? {
        let asset = AVURLAsset(url: videoURL)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
            return nil
        }
        
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        guard durationSeconds.isFinite, durationSeconds > 0 else {
            throw ExtractionError.unreadableAudio
        }
        
        let tempDirectory = try makeRunTempDirectory(prefix: "full")
        let outputURL = tempDirectory.appendingPathComponent("full_audio.wav")
        
        let exported = try exportWAVSegment(
            asset: asset,
            track: track,
            start: 0,
            duration: durationSeconds,
            outputURL: outputURL
        )
        
        return exported ? outputURL : nil
    }

    public func exportClassificationWindows(from videoURL: URL) async throws -> [ScreenRecordingAudioSegment] {
        let asset = AVURLAsset(url: videoURL)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
            return []
        }

        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        guard durationSeconds.isFinite, durationSeconds > 0 else {
            throw ExtractionError.unreadableAudio
        }

        let timestamps = classificationTimestamps(until: durationSeconds)
        guard !timestamps.isEmpty else { return [] }

        let tempDirectory = try makeRunTempDirectory(prefix: "windows")

        var segments: [ScreenRecordingAudioSegment] = []

        for timestamp in timestamps {
            let remaining = max(0, durationSeconds - timestamp)
            let segmentDuration = min(windowDuration, remaining)
            guard segmentDuration > 0.1 else { continue }

            let outputURL = tempDirectory
                .appendingPathComponent("audio-\(Int(timestamp * 1000)).wav")

            let exported = try exportWAVSegment(
                asset: asset,
                track: track,
                start: timestamp,
                duration: segmentDuration,
                outputURL: outputURL
            )
            if exported {
                segments.append(ScreenRecordingAudioSegment(timestamp: timestamp, wavURL: outputURL))
            }
        }

        return segments
    }

    private func classificationTimestamps(until durationSeconds: TimeInterval) -> [TimeInterval] {
        let interval = max(1, Int(windowDuration))
        var timestamps: [TimeInterval] = []
        var second = 0
        while TimeInterval(second) <= durationSeconds {
            timestamps.append(TimeInterval(second))
            second += interval
        }
        return timestamps
    }

    @discardableResult
    private func exportWAVSegment(
        asset: AVURLAsset,
        track: AVAssetTrack,
        start: TimeInterval,
        duration: TimeInterval,
        outputURL: URL
    ) throws -> Bool {
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = CMTimeRange(
            start: CMTime(seconds: start, preferredTimescale: 44100),
            duration: CMTime(seconds: duration, preferredTimescale: 44100)
        )

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
            AVSampleRateKey: whisperSampleRate,
            AVNumberOfChannelsKey: 1,
        ]

        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        output.alwaysCopiesSampleData = false
        reader.add(output)

        guard reader.startReading() else {
            throw reader.error ?? ExtractionError.exportFailed
        }

        // Collect raw PCM samples
        var pcmData = Data()
        while reader.status == .reading {
            guard let sampleBuffer = output.copyNextSampleBuffer(),
                  let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
                continue
            }
            let length = CMBlockBufferGetDataLength(blockBuffer)
            var chunk = Data(count: length)
            chunk.withUnsafeMutableBytes { rawBuffer in
                guard let base = rawBuffer.baseAddress else { return }
                CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: base)
            }
            pcmData.append(chunk)
        }

        if reader.status == .failed {
            throw reader.error ?? ExtractionError.exportFailed
        }

        guard !pcmData.isEmpty else { return false }

        // Use AVAudioFile to write a properly formatted WAV file
        try writeWAVUsingAVAudioFile(pcmData: pcmData, to: outputURL)
        return FileManager.default.fileExists(atPath: outputURL.path)
    }

    /// Writes PCM samples to disk using Apple's AVAudioFile API,
    /// which guarantees a valid WAV format that WhisperKit can open.
    private func writeWAVUsingAVAudioFile(pcmData: Data, to url: URL) throws {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: whisperSampleRate,
            channels: 1,
            interleaved: true
        ) else {
            throw ExtractionError.exportFailed
        }

        let frameCount = AVAudioFrameCount(pcmData.count / MemoryLayout<Int16>.size)
        guard frameCount > 0 else { throw ExtractionError.exportFailed }

        let audioFile = try AVAudioFile(
            forWriting: url,
            settings: format.settings,
            commonFormat: .pcmFormatInt16,
            interleaved: true
        )

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw ExtractionError.exportFailed
        }
        buffer.frameLength = frameCount

        pcmData.withUnsafeBytes { rawPtr in
            guard let src = rawPtr.bindMemory(to: Int16.self).baseAddress,
                  let dst = buffer.int16ChannelData?[0] else { return }
            dst.update(from: src, count: Int(frameCount))
        }

        try audioFile.write(from: buffer)
    }

    private func makeRunTempDirectory(prefix: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("screen-recording-audio", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let directory = root.appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
