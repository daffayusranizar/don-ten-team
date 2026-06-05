import Foundation
import UIKit

public actor PipelineOrchestrator {
    public init() {}
    
    /// The main entry point for the UI team to call
    public func processSession(
        videoURL: URL,
        child: Child? = nil,
        onProgress: SessionAnalysisProgressHandler? = nil
    ) async throws -> SessionAnalysisResult {
        print("[\(Date().formatted(date: .omitted, time: .standard))] 🚀 Starting PipelineOrchestrator.processSession...")

        func report(_ phase: SessionAnalysisProgress.Phase, _ fraction: Double, _ detail: String? = nil) {
            onProgress?(SessionAnalysisProgress(phase: phase, fraction: min(1, max(0, fraction)), detail: detail))
        }

        report(.preparingModels, 0.12, "Loading on-device models…")
        
        print("[\(Date().formatted(date: .omitted, time: .standard))] ⚙️ Step 1: Booting up engines...")
        let frameExtractor = ScreenRecordingFrameExtractor()
        let audioExtractor = ScreenRecordingAudioExtractor()
        let aggregator = ScreenRecordingAggregator()
        let summarizer = LLMSummarizer()
        
        let clipClassifier = try await MobileCLIPClassifier()
        let whisper = try await ScreenRecordingWhisperTranscriber()

        let metadata = try await frameExtractor.loadMetadata(from: videoURL)
        let estimatedFrameCount = max(1, metadata.estimatedFrameCount)
        
        report(.extractingAudio, 0.18, "Pulling audio from the recording…")
        print("[\(Date().formatted(date: .omitted, time: .standard))] 🔊 Step 2: Extracting audio windows and full audio track...")
        let audioSegments = try await audioExtractor.exportClassificationWindows(from: videoURL)
        let fullAudioURL = try await audioExtractor.exportFullAudio(from: videoURL)
        let hasAudioTrack = await audioExtractor.hasAudioTrack(in: videoURL)

        report(.transcribing, 0.35, "Listening with on-device speech recognition…")
        print("[\(Date().formatted(date: .omitted, time: .standard))] 🗣️ Step 3: Processing audio (\(audioSegments.count) windows, hasAudioTrack=\(hasAudioTrack))...")
        let windowDuration: TimeInterval = 3.0
        let fullTranscripts: [SegmentedTranscript]
        if let fullAudioURL {
            fullTranscripts = try await whisper.transcribeFull(wavURL: fullAudioURL)
        } else {
            fullTranscripts = []
        }
        let hasFullTrack = !fullTranscripts.isEmpty

        var audioResultsByBucket: [Int: String] = [:]

        try await withThrowingTaskGroup(of: (Int, String).self) { group in
            for segment in audioSegments {
                group.addTask {
                    let segmentStart = segment.timestamp
                    let segmentEnd = segmentStart + windowDuration
                    let bucket = Self.audioBucketKey(for: segmentStart, windowDuration: windowDuration)

                    var matchedTexts = fullTranscripts.filter { entry in
                        max(entry.start, segmentStart) < min(entry.end, segmentEnd)
                    }.map(\.text)
                    var rawTranscript = TranscriptSanitizer.sanitize(matchedTexts.joined(separator: " "))

                    if !hasFullTrack,
                       rawTranscript.isEmpty || !TranscriptSanitizer.isMeaningful(rawTranscript),
                       let fallback = try? await whisper.transcribe(wavURL: segment.wavURL),
                       !fallback.isEmpty {
                        rawTranscript = fallback
                    }

                    let storedTranscript = TranscriptSanitizer.meaningfulForStorage(rawTranscript) ?? ""
                    return (bucket, storedTranscript)
                }
            }

            for try await item in group {
                guard !item.1.isEmpty else { continue }
                if let existing = audioResultsByBucket[item.0], existing.count >= item.1.count {
                    continue
                }
                audioResultsByBucket[item.0] = item.1
            }
        }

        let windowsWithTranscript = audioResultsByBucket.count
        print(
            "[\(Date().formatted(date: .omitted, time: .standard))] 🗣️ Audio: \(windowsWithTranscript)/\(audioSegments.count) windows with transcript, full segments=\(fullTranscripts.count)"
        )

        let sessionTranscriptExcerpt = Self.sessionTranscriptExcerpt(
            fullTranscripts: fullTranscripts,
            audioResultsByBucket: audioResultsByBucket,
            windowsWithTranscript: windowsWithTranscript
        )
        
        report(.analyzingScreens, 0.38, "Starting screen analysis…")
        print("[\(Date().formatted(date: .omitted, time: .standard))] 🎞️ Step 4: Processing video frames in parallel batches...")
        typealias RawFrameType = (
            timestamp: TimeInterval,
            matches: [ClassificationMatch],
            thumbnail: UIImage?,
            bottomCropThumbnail: UIImage?,
            audioTranscript: String?,
            audioTone: String?,
            audioLabel: String?,
            videoMatchedPrompt: String?,
            audioMatchedPrompt: String?,
            contentSummary: String?,
            creatorHandle: String?
        )
        
        var rawFrames: [RawFrameType] = []
        var frameBatch: [ScreenRecordingFrame] = []
        
        @Sendable func processBatch(_ batch: [ScreenRecordingFrame]) async throws -> [RawFrameType] {
            print("[\(Date().formatted(date: .omitted, time: .standard))]    -> Processing batch of \(batch.count) frames concurrently...")
            return try await withThrowingTaskGroup(of: RawFrameType.self) { group in
                for frame in batch {
                    group.addTask {
                        let timestamp = frame.timestamp
                        let transcript = Self.resolvedTranscript(
                            at: timestamp,
                            from: audioResultsByBucket,
                            windowDuration: windowDuration
                        )

                        let clip = try await clipClassifier.classify(
                            pixelBuffer: frame.pixelBuffer,
                            temperature: 100,
                            topK: 5
                        )

                        let frameImages = ImagePreprocessor.frameDisplayImages(from: frame.pixelBuffer)
                        let categoryLabel = clip.categories.first?.label
                        let contentSummary = ScreenContentSummaryBuilder.segmentSummary(
                            label: categoryLabel ?? "Unknown",
                            transcript: transcript.isEmpty ? nil : transcript
                        )
                        
                        return (
                            timestamp: timestamp,
                            matches: clip.categories,
                            thumbnail: frameImages.thumbnail,
                            bottomCropThumbnail: frameImages.bottomCropThumbnail,
                            audioTranscript: transcript.isEmpty ? nil : transcript,
                            audioTone: nil,
                            audioLabel: nil,
                            videoMatchedPrompt: clip.prompts.first?.matchedPrompt,
                            audioMatchedPrompt: nil,
                            contentSummary: contentSummary,
                            creatorHandle: nil
                        )
                    }
                }
                
                var results: [RawFrameType] = []
                for try await result in group {
                    results.append(result)
                }
                return results
            }
        }

        try await frameExtractor.forEachFrame(from: videoURL) { frame in
            frameBatch.append(frame)
            if frameBatch.count >= 3 {
                let results = try await processBatch(frameBatch)
                rawFrames.append(contentsOf: results)
                frameBatch.removeAll()
                let screenFraction = 0.38 + (0.42 * Double(rawFrames.count) / Double(estimatedFrameCount))
                report(
                    .analyzingScreens,
                    screenFraction,
                    "Screen \(min(rawFrames.count, estimatedFrameCount)) of \(estimatedFrameCount)"
                )
            }
        }
        
        if !frameBatch.isEmpty {
            let results = try await processBatch(frameBatch)
            rawFrames.append(contentsOf: results)
            let screenFraction = 0.38 + (0.42 * Double(rawFrames.count) / Double(estimatedFrameCount))
            report(
                .analyzingScreens,
                screenFraction,
                "Screen \(min(rawFrames.count, estimatedFrameCount)) of \(estimatedFrameCount)"
            )
        }
        
        rawFrames.sort { $0.timestamp < $1.timestamp }
        
        report(.generatingSummary, 0.82, "Grouping results by time…")
        print("[\(Date().formatted(date: .omitted, time: .standard))] ⏱️ Step 5: Aggregating timeline (Fusion)...")
        let timeline = await aggregator.timeline(frames: rawFrames, fps: 1.0, intervalSeconds: 3)
        let categoryBreakdown = UsageCategoryBreakdown.from(timeline: timeline)
        let dominantCategory = categoryBreakdown.dominantCategoryName ?? "Mixed content"

        let fullTrackText = TranscriptSanitizer.sanitize(fullTranscripts.map(\.text).joined(separator: " "))
        let sessionTranscriptDigest = TranscriptDigestBuilder.buildDigest(
            timeline: timeline,
            fullTrackText: fullTrackText
        )
        let sessionTranscriptBriefSummary = TranscriptDigestBuilder.buildBriefSummary(
            fullTrackText: fullTrackText,
            digest: sessionTranscriptDigest
        )

        report(.generatingSummary, 0.88, "Writing parent-friendly summary…")
        print("[\(Date().formatted(date: .omitted, time: .standard))] 🧠 Step 6: Generating AI Summary...")
        let aiProseSummary: String
        do {
            var llmSummary = try await summarizer.summarizeRecording(
                timeline: timeline,
                overallCategory: dominantCategory,
                transcriptBrief: sessionTranscriptBriefSummary,
                child: child
            )
            if Self.looksLikeRawSegmentDump(llmSummary) {
                print("⚠️ LLM summary looked like raw segments; using structured fallback")
                llmSummary = ScreenContentSummaryBuilder.parentFacingRecordingSummary(
                    timeline: timeline,
                    dominantCategory: dominantCategory
                ) ?? llmSummary
            }
            aiProseSummary = llmSummary
        } catch {
            print("⚠️ LLM summary failed, using fallback: \(error)")
            aiProseSummary = ScreenContentSummaryBuilder.parentFacingRecordingSummary(
                timeline: timeline,
                dominantCategory: dominantCategory
            ) ?? Self.fallbackProseSummary(
                timeline: timeline,
                dominantCategory: dominantCategory
            )
        }
        
        report(.finalizing, 0.94, "Preparing session insights…")
        print("[\(Date().formatted(date: .omitted, time: .standard))] 💡 Step 7: Generating guidance...")
        let guidanceEngine = GuidanceEngine()
        let guidance = await guidanceEngine.generateGuidance(
            timeline: timeline,
            dominantCategory: dominantCategory,
            child: child
        )
        
        report(.finalizing, 1.0, "Almost done…")
        print("[\(Date().formatted(date: .omitted, time: .standard))] ✅ Pipeline complete! Returning results.")
        
        do {
            if FileManager.default.fileExists(atPath: videoURL.path) {
                try FileManager.default.removeItem(at: videoURL)
                print("🗑️ Automatically deleted processed video file: \(videoURL.lastPathComponent)")
            }
        } catch {
            print("⚠️ Failed to delete processed video: \(error)")
        }

        let result = SessionAnalysisResult(
            dominantCategory: ClassificationCategory(name: dominantCategory, prompts: []),
            aiProseSummary: aiProseSummary,
            guidance: guidance,
            timeline: timeline,
            categoryBreakdown: categoryBreakdown,
            sessionTranscriptExcerpt: sessionTranscriptExcerpt,
            sessionTranscriptDigest: sessionTranscriptDigest,
            sessionTranscriptBriefSummary: sessionTranscriptBriefSummary
        )
        #if DEBUG
        result.logToXcodeConsole()
        #endif
        return result
    }

    private static func sessionTranscriptExcerpt(
        fullTranscripts: [SegmentedTranscript],
        audioResultsByBucket: [Int: String],
        windowsWithTranscript: Int
    ) -> String? {
        let joined = TranscriptSanitizer.sanitize(fullTranscripts.map(\.text).joined(separator: " "))
        guard TranscriptSanitizer.isMeaningful(joined) else { return nil }
        if windowsWithTranscript >= max(2, audioResultsByBucket.count / 4) {
            return nil
        }
        let maxLen = 280
        if joined.count <= maxLen {
            return joined
        }
        let end = joined.index(joined.startIndex, offsetBy: maxLen)
        return String(joined[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private static func looksLikeRawSegmentDump(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower.contains("on screen:") && lower.contains("spoken:") { return true }
        if text.contains("… and ") && lower.contains("more segments") { return true }
        if lower.contains("everything on your screen") { return true }
        return text.filter(\.isNewline).count >= 3
    }

    private static func fallbackProseSummary(
        timeline: [FrameClassificationSummary],
        dominantCategory: String
    ) -> String {
        ScreenContentSummaryBuilder.parentFacingRecordingSummary(
            timeline: timeline,
            dominantCategory: dominantCategory
        ) ?? "We analyzed the recording but could not generate a detailed summary."
    }

    private static func audioBucketKey(for timestamp: TimeInterval, windowDuration: TimeInterval) -> Int {
        guard timestamp.isFinite, windowDuration > 0 else { return 0 }
        return Int((max(0, timestamp) / windowDuration).rounded())
    }

    private static func resolvedTranscript(
        at timestamp: TimeInterval,
        from buckets: [Int: String],
        windowDuration: TimeInterval
    ) -> String {
        let key = audioBucketKey(for: timestamp, windowDuration: windowDuration)
        let candidates = [key, key - 1, key + 1]
        for candidate in candidates {
            guard let transcript = buckets[candidate], !transcript.isEmpty else { continue }
            return transcript
        }
        return ""
    }
}

#if DEBUG
extension PipelineOrchestrator {
    static func runAudioMappingRegressionChecks() {
        let interval: TimeInterval = 3.0
        assert(audioBucketKey(for: 3.0, windowDuration: interval) == 1)
        assert(audioBucketKey(for: 3.03, windowDuration: interval) == 1)
        assert(audioBucketKey(for: 2.98, windowDuration: interval) == 1)

        let exactMatch = resolvedTranscript(
            at: 3.03,
            from: [1: "exact transcript"],
            windowDuration: interval
        )
        assert(exactMatch == "exact transcript")

        let neighborMatch = resolvedTranscript(
            at: 3.0,
            from: [2: "neighbor transcript"],
            windowDuration: interval
        )
        assert(neighborMatch == "neighbor transcript")
    }
}
#endif
