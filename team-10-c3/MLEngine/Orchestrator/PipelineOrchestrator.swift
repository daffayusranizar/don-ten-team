import CoreVideo
import Foundation
import UIKit

public actor PipelineOrchestrator {
    public init() {}

    private typealias RawFrameType = (
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
        onScreenTranscript: String?,
        creatorHandle: String?
    )

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
        let pipelineStartedAt = ContinuousClock.now
        var lastCheckpoint = pipelineStartedAt
        func logTiming(_ label: String) {
            let now = ContinuousClock.now
            let delta = lastCheckpoint.duration(to: now)
            let total = pipelineStartedAt.duration(to: now)
            print("⏱️ Analysis timing: \(label) +\(delta) total \(total)")
            lastCheckpoint = now
        }

        report(.preparingModels, 0.12, "Loading on-device models…")
        
        print("[\(Date().formatted(date: .omitted, time: .standard))] ⚙️ Step 1: Booting up engines...")
        let frameExtractor = ScreenRecordingFrameExtractor()
        let audioExtractor = ScreenRecordingAudioExtractor()
        let aggregator = ScreenRecordingAggregator()
        let summarizer = LLMSummarizer()
        let audioTranscriptAnalyzer = AudioTranscriptAnalyzer(window: .defaultPhase2)
        let visualTranscriptAnalyzer = VisualTranscriptAnalyzer(window: .defaultPhase2)
        
        let clipClassifier = try await MobileCLIPClassifier()
        let whisper = try await ScreenRecordingWhisperTranscriber()
        logTiming("model load")

        let metadata = try await frameExtractor.loadMetadata(from: videoURL)
        let estimatedFrameCount = max(1, metadata.estimatedFrameCount)
        logTiming("metadata load")

        let windowDuration = TimeInterval(BroadcastConstants.classificationIntervalSeconds)
        report(.extractingAudio, 0.18, "Preparing audio transcription…")
        print("[\(Date().formatted(date: .omitted, time: .standard))] 🔊 Step 2: Preparing audio pipeline...")
        async let audioProcessing = audioTranscriptAnalyzer.analyze(
            videoURL: videoURL,
            duration: metadata.duration,
            audioExtractor: audioExtractor,
            whisper: whisper,
            windowDuration: windowDuration
        )
        logTiming("audio task started")

        report(.transcribing, 0.35, "Listening with on-device speech recognition…")
        print("[\(Date().formatted(date: .omitted, time: .standard))] 🗣️ Step 3: Processing audio and video in parallel...")
        
        report(.analyzingScreens, 0.38, "Starting screen analysis…")
        print("[\(Date().formatted(date: .omitted, time: .standard))] 🎞️ Step 4: Processing video frames in parallel batches...")
        var rawFrames: [RawFrameType] = []
        var visualCandidates: [VisualTranscriptCandidate] = []
        var frameBatch: [ScreenRecordingFrame] = []
        
        @Sendable func processBatch(_ batch: [ScreenRecordingFrame]) async throws -> [RawFrameType] {
            print("[\(Date().formatted(date: .omitted, time: .standard))]    -> Processing batch of \(batch.count) frames concurrently...")
            return try await withThrowingTaskGroup(of: RawFrameType.self) { group in
                for frame in batch {
                    group.addTask {
                        let timestamp = frame.timestamp

                        let clip = try await clipClassifier.classify(
                            pixelBuffer: frame.pixelBuffer,
                            temperature: 100,
                            topK: 5
                        )

                        let frameImages = ImagePreprocessor.frameDisplayImages(from: frame.pixelBuffer)
                        let categoryLabel = clip.categories.first?.label
                        let onScreenTranscript = await ScreenTextRecognizer.recognizeText(in: frame.pixelBuffer)
                        let contentSummary = ScreenContentSummaryBuilder.segmentSummary(
                            label: categoryLabel ?? "Unknown",
                            transcript: nil,
                            onScreenTranscript: onScreenTranscript
                        )
                        
                        return (
                            timestamp: timestamp,
                            matches: clip.categories,
                            thumbnail: frameImages.thumbnail,
                            bottomCropThumbnail: frameImages.bottomCropThumbnail,
                            audioTranscript: nil,
                            audioTone: nil,
                            audioLabel: nil,
                            videoMatchedPrompt: clip.prompts.first?.matchedPrompt,
                            audioMatchedPrompt: nil,
                            contentSummary: contentSummary,
                            onScreenTranscript: onScreenTranscript,
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
        visualCandidates = rawFrames.map { frame in
            let segmentKey = Self.audioBucketKey(for: frame.timestamp, windowDuration: windowDuration)
            return VisualTranscriptCandidate(
                segmentKey: segmentKey,
                timestamp: frame.timestamp,
                text: frame.onScreenTranscript ?? ""
            )
        }
        logTiming("frame analysis")

        let audioResult = try await audioProcessing
        let visualResult = await visualTranscriptAnalyzer.analyze(
            candidates: visualCandidates,
            totalDuration: metadata.duration
        )
        logTiming("audio processing complete")
        print(
            "[\(Date().formatted(date: .omitted, time: .standard))] 🗣️ Audio: buckets=\(audioResult.bucketedTranscripts.count), fallback=\(audioResult.usedFallbackWindows), coverage=\(audioResult.coverage), hasAudioTrack=\(audioResult.hasAudioTrack), fullSegments=\(audioResult.fullTrackSegments.count)"
        )
        print(
            "[\(Date().formatted(date: .omitted, time: .standard))] 👀 Visual: useful=\(visualResult.usefulSegmentCount), dropped=\(visualResult.lowSignalDropCount)"
        )

        rawFrames = rawFrames.map { frame in
            let segmentKey = Self.audioBucketKey(for: frame.timestamp, windowDuration: windowDuration)
            let visualText = visualResult.segmentVisualText[segmentKey]
            let categoryLabel = frame.matches.first?.label ?? "Unknown"
            let contentSummary = ScreenContentSummaryBuilder.segmentSummary(
                label: categoryLabel,
                transcript: nil,
                onScreenTranscript: visualText
            )
            return (
                timestamp: frame.timestamp,
                matches: frame.matches,
                thumbnail: frame.thumbnail,
                bottomCropThumbnail: frame.bottomCropThumbnail,
                audioTranscript: nil,
                audioTone: frame.audioTone,
                audioLabel: frame.audioLabel,
                videoMatchedPrompt: frame.videoMatchedPrompt,
                audioMatchedPrompt: frame.audioMatchedPrompt,
                contentSummary: contentSummary,
                onScreenTranscript: visualText,
                creatorHandle: frame.creatorHandle
            )
        }
        logTiming("attach transcripts")

        let sessionTranscriptExcerpt = Self.sessionTranscriptExcerpt(
            fullTranscripts: audioResult.fullTrackSegments
        )
        
        report(.generatingSummary, 0.82, "Grouping results by time…")
        print("[\(Date().formatted(date: .omitted, time: .standard))] ⏱️ Step 5: Aggregating timeline (Fusion)...")
        var timeline = await aggregator.timeline(
            frames: rawFrames,
            fps: 1.0,
            intervalSeconds: BroadcastConstants.classificationIntervalSeconds
        )
        if Self.shouldGenerateOnScreenBriefs(for: timeline) {
            timeline = await Self.timelineWithOnScreenBriefs(timeline: timeline, summarizer: summarizer)
        }
        logTiming("timeline aggregation")
        let categoryBreakdown = UsageCategoryBreakdown.from(timeline: timeline)
        let dominantCategory = categoryBreakdown.dominantCategoryName ?? "Mixed content"

        let fullTrackText = TranscriptSanitizer.sanitize(audioResult.fullTrackSegments.map(\.text).joined(separator: " "))
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
                fullTrackTranscript: fullTrackText,
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
        logTiming("session summary")
        
        report(.finalizing, 0.94, "Preparing session insights…")
        print("[\(Date().formatted(date: .omitted, time: .standard))] 💡 Step 7: Generating guidance...")
        let guidanceEngine = GuidanceEngine()
        let guidance = await guidanceEngine.generateGuidance(
            timeline: timeline,
            dominantCategory: dominantCategory,
            child: child
        )
        logTiming("guidance")
        
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
        logTiming("final result")
        return result
    }

    private static func sessionTranscriptExcerpt(
        fullTranscripts: [SegmentedTranscript]
    ) -> String? {
        let joined = TranscriptSanitizer.sanitize(fullTranscripts.map(\.text).joined(separator: " "))
        guard TranscriptSanitizer.isMeaningful(joined) else { return nil }
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

    private static func timelineWithOnScreenBriefs(
        timeline: [FrameClassificationSummary],
        summarizer: LLMSummarizer
    ) async -> [FrameClassificationSummary] {
        let segments = timeline.compactMap { entry -> (id: Int, ocr: String, category: String)? in
            guard let ocr = entry.onScreenTranscript,
                  OnScreenTextSanitizer.isUsefulOnScreenContent(ocr) else { return nil }
            return (entry.id, ocr, entry.label)
        }
        guard !segments.isEmpty else { return timeline }

        let briefs = await summarizer.summarizeOnScreenBriefs(segments: segments)
        guard !briefs.isEmpty else { return timeline }

        return timeline.map { entry in
            guard let brief = briefs[entry.id] else { return entry }
            return FrameClassificationSummary(
                id: entry.id,
                timestamp: entry.timestamp,
                label: entry.label,
                matchedPrompt: entry.matchedPrompt,
                videoMatchedPrompt: entry.videoMatchedPrompt,
                audioMatchedPrompt: entry.audioMatchedPrompt,
                probability: entry.probability,
                thumbnail: entry.thumbnail,
                bottomCropThumbnail: entry.bottomCropThumbnail,
                audioTranscript: entry.audioTranscript,
                audioTone: entry.audioTone,
                audioLabel: entry.audioLabel,
                contentSummary: entry.contentSummary,
                onScreenTranscript: entry.onScreenTranscript,
                onScreenBriefSummary: brief,
                creatorHandle: entry.creatorHandle
            )
        }
    }

    private static func shouldGenerateOnScreenBriefs(for timeline: [FrameClassificationSummary]) -> Bool {
        let usefulOCRCount = timeline.reduce(into: 0) { count, entry in
            if let ocr = entry.onScreenTranscript,
               OnScreenTextSanitizer.isUsefulOnScreenContent(ocr) {
                count += 1
            }
        }
        return usefulOCRCount >= 30
    }

    private static func audioBucketKey(for timestamp: TimeInterval, windowDuration: TimeInterval) -> Int {
        guard timestamp.isFinite, windowDuration > 0 else { return 0 }
        return Int((max(0, timestamp) / windowDuration).rounded())
    }

}

#if DEBUG
extension PipelineOrchestrator {
    static func runAudioMappingRegressionChecks() {
        let interval = TimeInterval(BroadcastConstants.classificationIntervalSeconds)
        assert(audioBucketKey(for: 2.0, windowDuration: interval) == 1)
        assert(audioBucketKey(for: 2.02, windowDuration: interval) == 1)
        assert(audioBucketKey(for: 1.98, windowDuration: interval) == 1)
    }
}
#endif
