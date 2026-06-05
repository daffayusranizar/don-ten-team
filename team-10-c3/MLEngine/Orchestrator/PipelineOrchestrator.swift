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
        
        // 1. Boot up the engines (This happens in the background)
        print("[\(Date().formatted(date: .omitted, time: .standard))] ⚙️ Step 1: Booting up engines...")
        let frameExtractor = ScreenRecordingFrameExtractor()
        let audioExtractor = ScreenRecordingAudioExtractor()
        let aggregator = ScreenRecordingAggregator()
        let summarizer = LLMSummarizer()
        
        let clipClassifier = try await MobileCLIPClassifier()
        let whisper = try await ScreenRecordingWhisperTranscriber()
        let toneAnalyzer = ScreenRecordingAudioToneAnalyzer()
        let visionAnalyzer = VisionFrameContentAnalyzer()
        let handleExtractor = CreatorHandleExtractor()
        let sentimentAnalyzer = ScreenRecordingSentimentAnalyzer()

        let metadata = try await frameExtractor.loadMetadata(from: videoURL)
        let estimatedFrameCount = max(1, metadata.estimatedFrameCount)
        
        // 2. Extract Audio First
        report(.extractingAudio, 0.18, "Pulling audio from the recording…")
        print("[\(Date().formatted(date: .omitted, time: .standard))] 🔊 Step 2: Extracting audio windows and full audio track...")
        let audioSegments = try await audioExtractor.exportClassificationWindows(from: videoURL)
        let fullAudioURL = try await audioExtractor.exportFullAudio(from: videoURL)
        let hasAudioTrack = await audioExtractor.hasAudioTrack(in: videoURL)

        // 3. Process Audio (Full Transcript + per-window tone/transcript)
        report(.transcribing, 0.28, "Listening with on-device speech recognition…")
        print("[\(Date().formatted(date: .omitted, time: .standard))] 🗣️ Step 3: Processing audio (\(audioSegments.count) windows, hasAudioTrack=\(hasAudioTrack))...")
        let windowDuration: TimeInterval = 3.0
        let fullTranscripts: [SegmentedTranscript]
        if let fullAudioURL {
            fullTranscripts = try await whisper.transcribeFull(wavURL: fullAudioURL)
        } else {
            fullTranscripts = []
        }

        var audioResults: [TimeInterval: (transcript: String, pcmTone: String)] = [:]

        try await withThrowingTaskGroup(
            of: (TimeInterval, String, String).self
        ) { group in
            for segment in audioSegments {
                group.addTask {
                    let segmentStart = segment.timestamp
                    let segmentEnd = segmentStart + windowDuration

                    var matchedTexts = fullTranscripts.filter { entry in
                        max(entry.start, segmentStart) < min(entry.end, segmentEnd)
                    }.map(\.text)
                    var rawTranscript = TranscriptSanitizer.sanitize(matchedTexts.joined(separator: " "))

                    if rawTranscript.isEmpty || !TranscriptSanitizer.isMeaningful(rawTranscript) {
                        if let fallback = try? await whisper.transcribe(wavURL: segment.wavURL),
                           !fallback.isEmpty {
                            rawTranscript = fallback
                        }
                    }

                    let storedTranscript = AudioToneResolver.storageTranscript(rawTranscript) ?? ""
                    let analysis = await toneAnalyzer.analyze(
                        wavURL: segment.wavURL,
                        transcript: storedTranscript,
                        durationSeconds: windowDuration
                    )
                    return (segmentStart, storedTranscript, analysis.description)
                }
            }

            for try await item in group {
                audioResults[item.0] = (transcript: item.1, pcmTone: item.2)
            }
        }

        let windowsWithTranscript = audioResults.values.filter { !$0.transcript.isEmpty }.count
        print(
            "[\(Date().formatted(date: .omitted, time: .standard))] 🗣️ Audio: \(windowsWithTranscript)/\(audioSegments.count) windows with transcript, full segments=\(fullTranscripts.count)"
        )

        let sessionTranscriptExcerpt = Self.sessionTranscriptExcerpt(
            fullTranscripts: fullTranscripts,
            audioResults: audioResults,
            windowsWithTranscript: windowsWithTranscript
        )
        
        // 4. Process Video Frames
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
            creatorHandle: String?,
            isDuplicate: Bool
        )
        
        var rawFrames: [RawFrameType] = []
        var frameBatch: [ScreenRecordingFrame] = []
        
        @Sendable func processBatch(_ batch: [ScreenRecordingFrame]) async throws -> [RawFrameType] {
            print("[\(Date().formatted(date: .omitted, time: .standard))]    -> Processing batch of \(batch.count) frames concurrently...")
            return try await withThrowingTaskGroup(of: RawFrameType.self) { group in
                for frame in batch {
                    group.addTask {
                        let timestamp = frame.timestamp
                        let audioInfo = audioResults[timestamp] ?? (transcript: "", pcmTone: AudioToneLabels.silentDescription)
                        
                        if frame.isDuplicateOfPrevious {
                            let displayTone = AudioToneResolver.resolveDisplayTone(
                                pcmDescription: audioInfo.pcmTone,
                                transcript: audioInfo.transcript,
                                categoryLabel: nil,
                                contentSummary: nil
                            )
                            print("[\(Date().formatted(date: .omitted, time: .standard))]      ⚡️ Skipped ML for duplicate frame at \(timestamp)s")
                            return (
                                timestamp: timestamp,
                                matches: [],
                                thumbnail: nil,
                                bottomCropThumbnail: nil,
                                audioTranscript: audioInfo.transcript.isEmpty ? nil : audioInfo.transcript,
                                audioTone: displayTone,
                                audioLabel: nil,
                                videoMatchedPrompt: nil,
                                audioMatchedPrompt: nil,
                                contentSummary: nil,
                                creatorHandle: nil,
                                isDuplicate: true
                            )
                        }
                        
                        // Run ML sequentially per frame to avoid Neural Engine thrashing, 
                        // but the batch of 3 frames will still process concurrently!
                        let vision = await visionAnalyzer.analyze(pixelBuffer: frame.pixelBuffer)
                        let handle = await handleExtractor.extract(from: frame.pixelBuffer)
                        let clip = try await clipClassifier.classify(
                            pixelBuffer: frame.pixelBuffer,
                            temperature: 100,
                            topK: 5
                        )

                        let frameImages = ImagePreprocessor.frameDisplayImages(from: frame.pixelBuffer)
                        let categoryLabel = clip.categories.first?.label
                        let displayTone = AudioToneResolver.resolveDisplayTone(
                            pcmDescription: audioInfo.pcmTone,
                            transcript: audioInfo.transcript,
                            categoryLabel: categoryLabel,
                            contentSummary: nil
                        )
                        let contentSummary = ScreenContentSummaryBuilder.segmentSummary(
                            label: categoryLabel ?? "Unknown",
                            onScreenText: vision.onScreenText,
                            sceneHints: vision.sceneHints,
                            transcript: audioInfo.transcript,
                            audioTone: displayTone
                        )
                        let resolvedTone = AudioToneResolver.resolveDisplayTone(
                            pcmDescription: audioInfo.pcmTone,
                            transcript: audioInfo.transcript,
                            categoryLabel: categoryLabel,
                            contentSummary: contentSummary
                        )
                        
                        return (
                            timestamp: timestamp,
                            matches: clip.categories,
                            thumbnail: frameImages.thumbnail,
                            bottomCropThumbnail: frameImages.bottomCropThumbnail,
                            audioTranscript: audioInfo.transcript.isEmpty ? nil : audioInfo.transcript,
                            audioTone: resolvedTone,
                            audioLabel: nil, 
                            videoMatchedPrompt: clip.prompts.first?.matchedPrompt,
                            audioMatchedPrompt: nil,
                            contentSummary: contentSummary,
                            creatorHandle: handle.handle,
                            isDuplicate: false
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
        
        // Ensure chronological order after parallel execution
        rawFrames.sort { $0.timestamp < $1.timestamp }
        
        // Resolve duplicates sequentially
        for i in 1..<rawFrames.count {
            if rawFrames[i].isDuplicate {
                rawFrames[i].matches = rawFrames[i-1].matches
                rawFrames[i].videoMatchedPrompt = rawFrames[i-1].videoMatchedPrompt
                rawFrames[i].contentSummary = rawFrames[i-1].contentSummary
                rawFrames[i].creatorHandle = rawFrames[i-1].creatorHandle
                rawFrames[i].thumbnail = rawFrames[i-1].thumbnail
                rawFrames[i].bottomCropThumbnail = rawFrames[i-1].bottomCropThumbnail
                rawFrames[i].audioTranscript = rawFrames[i-1].audioTranscript
                rawFrames[i].audioTone = rawFrames[i-1].audioTone
                rawFrames[i].audioLabel = rawFrames[i-1].audioLabel
            }
        }
        
        // 5. Aggregate Timeline (Fuse Audio and Video mathematically)
        report(.generatingSummary, 0.82, "Grouping results by time…")
        print("[\(Date().formatted(date: .omitted, time: .standard))] ⏱️ Step 5: Aggregating timeline (Fusion)...")
        let timeline = await aggregator.timeline(frames: rawFrames, fps: 1.0, intervalSeconds: 3)
        let categoryBreakdown = UsageCategoryBreakdown.from(timeline: timeline)
        
        // 6. Generate the Final AI Summary
        report(.generatingSummary, 0.88, "Writing parent-friendly summary…")
        print("[\(Date().formatted(date: .omitted, time: .standard))] 🧠 Step 6: Generating AI Summary...")
        let dominantCategory = timeline.first?.label ?? "Mixed content"
        let aiProseSummary: String
        do {
            var llmSummary = try await summarizer.summarizeRecording(
                timeline: timeline,
                overallCategory: dominantCategory,
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
        
        // 7. Extract Top Creators
        print("[\(Date().formatted(date: .omitted, time: .standard))] 👤 Step 7: Extracting top creators...")
        let allHandles = rawFrames.compactMap { $0.creatorHandle }
        let handleCounts = Dictionary(allHandles.map { ($0, Int(1)) }, uniquingKeysWith: +)
        let topCreators = handleCounts.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
        
        // 8. Generate Guidance
        report(.finalizing, 0.94, "Preparing session insights…")
        print("[\(Date().formatted(date: .omitted, time: .standard))] 💡 Step 8: Generating insights and guidance...")
        let guidanceEngine = GuidanceEngine()
        let insights = await guidanceEngine.generateInsights(
            timeline: timeline, 
            dominantCategory: dominantCategory,
            child: child
        )
        
        var concernSignals = insights.signals
        let fullTranscriptString = TranscriptSanitizer.sanitize(
            fullTranscripts.map(\.text).joined(separator: " ")
        )
        let sentimentInput: String
        if TranscriptSanitizer.isSubstantialForSentiment(fullTranscriptString) {
            sentimentInput = fullTranscriptString
        } else if let excerpt = sessionTranscriptExcerpt,
                  TranscriptSanitizer.isSubstantialForSentiment(excerpt) {
            sentimentInput = excerpt
        } else {
            sentimentInput = ""
        }
        let silentFrameCount = timeline.filter {
            AudioToneLabels.isSilentDescription($0.audioTone ?? "")
        }.count
        let silentMajority = !timeline.isEmpty && silentFrameCount > timeline.count / 2

        let sentimentResult = await sentimentAnalyzer.analyze(transcript: sentimentInput)
        if sentimentResult.isHighlyNegative,
           !sentimentInput.isEmpty,
           !silentMajority {
            let description: String
            if let snippet = sentimentResult.mostNegativeSnippet,
               TranscriptSanitizer.isQuotableSnippet(snippet) {
                description = """
                Highly negative sentiment was detected in the video's audio. For example: "\(snippet)"
                """
            } else {
                description = "Highly negative sentiment was detected in the video's audio."
            }
            concernSignals.append(ConcernSignal(
                title: "Negative Audio Detected",
                description: description,
                severity: .high
            ))
        }
        
        report(.finalizing, 1.0, "Almost done…")
        // 9. Cleanup & Return the beautiful result to the UI!
        print("[\(Date().formatted(date: .omitted, time: .standard))] ✅ Pipeline complete! Returning results.")
        
        // Auto-delete the video file to save disk space
        do {
            if FileManager.default.fileExists(atPath: videoURL.path) {
                try FileManager.default.removeItem(at: videoURL)
                print("🗑️ Automatically deleted processed video file: \(videoURL.lastPathComponent)")
            }
        } catch {
            print("⚠️ Failed to delete processed video: \(error)")
        }
        
        let fullTrackText = TranscriptSanitizer.sanitize(fullTranscripts.map(\.text).joined(separator: " "))
        let sessionTranscriptDigest = TranscriptDigestBuilder.buildDigest(
            timeline: timeline,
            fullTrackText: fullTrackText
        )
        let sessionToneSummary = SessionToneSummarizer.summarize(timeline: timeline)

        return SessionAnalysisResult(
            dominantCategory: ClassificationCategory(name: dominantCategory, prompts: []),
            aiProseSummary: aiProseSummary,
            topCreatorsSeen: topCreators,
            concernSignals: concernSignals,
            guidance: insights.guidance,
            timeline: timeline,
            categoryBreakdown: categoryBreakdown,
            sessionTranscriptExcerpt: sessionTranscriptExcerpt,
            sessionTranscriptDigest: sessionTranscriptDigest,
            sessionToneSummary: sessionToneSummary
        )
    }

    /// When per-window alignment is sparse but full-track Whisper succeeded, surface a short excerpt on the result screen.
    private static func sessionTranscriptExcerpt(
        fullTranscripts: [SegmentedTranscript],
        audioResults: [TimeInterval: (transcript: String, pcmTone: String)],
        windowsWithTranscript: Int
    ) -> String? {
        let joined = TranscriptSanitizer.sanitize(fullTranscripts.map(\.text).joined(separator: " "))
        guard TranscriptSanitizer.isMeaningful(joined) else { return nil }
        if windowsWithTranscript >= max(2, audioResults.count / 4) {
            return nil
        }
        let maxLen = 280
        if joined.count <= maxLen {
            return joined
        }
        let end = joined.index(joined.startIndex, offsetBy: maxLen)
        return String(joined[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    /// Detects the old fallback format (newline-joined segment OCR) mistakenly shown as AI Summary.
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
}
