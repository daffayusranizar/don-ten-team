import Foundation
@preconcurrency import WhisperKit

public struct SegmentedTranscript: Sendable {
    public let start: TimeInterval
    public let end: TimeInterval
    public let text: String
}

public enum WhisperTranscriberError: LocalizedError {
    case loadFailed(String)
    case transcriptionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .loadFailed(let message):
            return "Failed to load Whisper model: \(message)"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        }
    }
}

/// On-device Whisper base transcription via WhisperKit. 
/// Converted to an actor for safe background thread execution.
public actor ScreenRecordingWhisperTranscriber {
    private let sharedModelName = "base"
    private let whisperKit: WhisperKit
    private let decodeOptions = DecodingOptions(
        task: .transcribe,
        skipSpecialTokens: true,
        withoutTimestamps: true
    )

    public init() async throws {
        do {
            whisperKit = try await WhisperKit(
                WhisperKitConfig(model: sharedModelName)
            )
        } catch {
            throw WhisperTranscriberError.loadFailed(error.localizedDescription)
        }
    }

    public func transcribe(wavURL: URL) async throws -> String {
        let path = wavURL.path
        guard FileManager.default.fileExists(atPath: path) else {
            return ""
        }

        do {
            let results = try await whisperKit.transcribe(
                audioPath: path,
                decodeOptions: decodeOptions
            )
            return TranscriptSanitizer.sanitize(
                results
                    .compactMap(\.text)
                    .joined(separator: " ")
            )
        } catch {
            throw WhisperTranscriberError.transcriptionFailed(error.localizedDescription)
        }
    }

    public func transcribeFull(wavURL: URL) async throws -> [SegmentedTranscript] {
        let path = wavURL.path
        guard FileManager.default.fileExists(atPath: path) else {
            return []
        }

        do {
            let results = try await whisperKit.transcribe(
                audioPath: path,
                decodeOptions: decodeOptions
            )
            return results.flatMap { result in
                result.segments.compactMap { segment in
                    let text = TranscriptSanitizer.sanitize(segment.text)
                    guard TranscriptSanitizer.isMeaningful(text) else { return nil }
                    return SegmentedTranscript(
                        start: TimeInterval(segment.start),
                        end: TimeInterval(segment.end),
                        text: text
                    )
                }
            }
        } catch {
            throw WhisperTranscriberError.transcriptionFailed(error.localizedDescription)
        }
    }
}