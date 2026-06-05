import Foundation

actor AudioTranscriptAnalyzer {
    private let window: TranscriptAnalysisWindow

    init(window: TranscriptAnalysisWindow = .defaultPhase2) {
        self.window = window
    }

    func analyze(
        videoURL: URL,
        duration: TimeInterval,
        audioExtractor: ScreenRecordingAudioExtractor,
        whisper: ScreenRecordingWhisperTranscriber,
        windowDuration: TimeInterval
    ) async throws -> AudioTranscriptAnalysisResult {
        let fullAudioURL = try await audioExtractor.exportFullAudio(from: videoURL)
        let hasAudioTrack = await audioExtractor.hasAudioTrack(in: videoURL)
        let fullTranscripts = await transcribeFullAudioIfAvailable(fullAudioURL, whisper: whisper)
        let filteredFull = fullTranscripts.filter { segment in
            window.contains(segment.start, in: duration) || window.contains(segment.end, in: duration)
        }

        if !filteredFull.isEmpty {
            let bucketed = bucketedTranscripts(filteredFull, windowDuration: windowDuration)
            let coverage = Self.transcriptCoverage(
                bucketCount: bucketed.count,
                duration: duration,
                windowDuration: windowDuration
            )
            return AudioTranscriptAnalysisResult(
                bucketedTranscripts: bucketed,
                fullTrackSegments: filteredFull,
                coverage: coverage,
                usedFallbackWindows: false,
                hasAudioTrack: hasAudioTrack,
                analyzedDuration: duration
            )
        }

        let audioSegments = try await audioExtractor.exportClassificationWindows(from: videoURL)
        let fallbackBuckets = await transcribeFallbackWindows(
            audioSegments,
            duration: duration,
            whisper: whisper,
            windowDuration: windowDuration
        )
        let coverage = Self.transcriptCoverage(
            bucketCount: fallbackBuckets.count,
            duration: duration,
            windowDuration: windowDuration
        )
        return AudioTranscriptAnalysisResult(
            bucketedTranscripts: fallbackBuckets,
            fullTrackSegments: [],
            coverage: coverage,
            usedFallbackWindows: !fallbackBuckets.isEmpty,
            hasAudioTrack: hasAudioTrack,
            analyzedDuration: duration
        )
    }

    private func transcribeFullAudioIfAvailable(
        _ fullAudioURL: URL?,
        whisper: ScreenRecordingWhisperTranscriber
    ) async -> [SegmentedTranscript] {
        guard let fullAudioURL else { return [] }
        return (try? await whisper.transcribeFull(wavURL: fullAudioURL)) ?? []
    }

    private func bucketedTranscripts(
        _ transcripts: [SegmentedTranscript],
        windowDuration: TimeInterval
    ) -> [Int: String] {
        guard windowDuration > 0 else { return [:] }
        var buckets: [Int: [String]] = [:]

        for entry in transcripts {
            let startBucket = Self.audioBucketKey(for: entry.start, windowDuration: windowDuration)
            let endBucket = Self.audioBucketKey(for: entry.end, windowDuration: windowDuration)
            for bucket in min(startBucket, endBucket)...max(startBucket, endBucket) {
                buckets[bucket, default: []].append(entry.text)
            }
        }

        return buckets.reduce(into: [Int: String]()) { partial, item in
            let joined = TranscriptSanitizer.sanitize(item.value.joined(separator: " "))
            if let meaningful = TranscriptSanitizer.meaningfulForStorage(joined) {
                partial[item.key] = meaningful
            }
        }
    }

    private func transcribeFallbackWindows(
        _ segments: [ScreenRecordingAudioSegment],
        duration: TimeInterval,
        whisper: ScreenRecordingWhisperTranscriber,
        windowDuration: TimeInterval
    ) async -> [Int: String] {
        var results: [Int: String] = [:]
        let analysisWindow = window
        await withTaskGroup(of: (Int, String?).self) { group in
            for segment in segments {
                group.addTask {
                    guard analysisWindow.contains(segment.timestamp, in: duration) else {
                        return (0, nil)
                    }
                    let bucket = Self.audioBucketKey(for: segment.timestamp, windowDuration: windowDuration)
                    let fallback = try? await whisper.transcribe(wavURL: segment.wavURL)
                    let cleaned = TranscriptSanitizer.meaningfulForStorage(fallback ?? "")
                    return (bucket, cleaned)
                }
            }

            for await item in group {
                guard let transcript = item.1, !transcript.isEmpty else { continue }
                if let existing = results[item.0], existing.count >= transcript.count {
                    continue
                }
                results[item.0] = transcript
            }
        }
        return results
    }

    private static func transcriptCoverage(
        bucketCount: Int,
        duration: TimeInterval,
        windowDuration: TimeInterval
    ) -> Double {
        guard duration > 0, windowDuration > 0 else { return 0 }
        let expected = max(1, Int(floor(duration / windowDuration)) + 1)
        return min(1, Double(bucketCount) / Double(expected))
    }

    private static func audioBucketKey(for timestamp: TimeInterval, windowDuration: TimeInterval) -> Int {
        guard timestamp.isFinite, windowDuration > 0 else { return 0 }
        return Int((max(0, timestamp) / windowDuration).rounded())
    }
}
