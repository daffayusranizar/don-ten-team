import Foundation

/// Preloads and caches the on-device Whisper model so splash-screen warm-up is reused by the pipeline.
public enum WhisperModelLoader {
    private static let cache = Cache()

    public static func preload() async throws {
        try await cache.preload()
    }

    public static func shared() async throws -> ScreenRecordingWhisperTranscriber {
        try await cache.shared()
    }
}

private actor Cache {
    private var transcriber: ScreenRecordingWhisperTranscriber?

    func preload() async throws {
        guard transcriber == nil else { return }
        transcriber = try await ScreenRecordingWhisperTranscriber()
    }

    func shared() async throws -> ScreenRecordingWhisperTranscriber {
        if let transcriber {
            return transcriber
        }
        let loaded = try await ScreenRecordingWhisperTranscriber()
        transcriber = loaded
        return loaded
    }
}
