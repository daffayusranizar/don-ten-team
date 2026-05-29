import Foundation
import UIKit

public actor PipelineOrchestrator {
    public init() {}
    
    /// The main entry point for the UI team to call
    public func processSession(videoURL: URL, child: Child? = nil) async throws -> SessionAnalysisResult {
        print("[\(Date().formatted(date: .omitted, time: .standard))] 🚀 Starting PipelineOrchestrator.processSession...")
        
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
        
        // 2. Extract Audio First
        print("[\(Date().formatted(date: .omitted, time: .standard))] 🔊 Step 2: Extracting audio windows and full audio track...")
        let audioSegments = try await audioExtractor.exportClassificationWindows(from: videoURL)
        let fullAudioURL = try await audioExtractor.exportFullAudio(from: videoURL)
        
        // 3. Process Audio (Full Transcript + Parallel Tones)
        print("[\(Date().formatted(date: .omitted, time: .standard))] 🗣️ Step 3: Processing full audio transcript and \(audioSegments.count) tones...")
        var audioResults: [TimeInterval: (transcript: String, tone: String)] = [:]
        
        let fullTranscripts = fullAudioURL != nil ? try await whisper.transcribeFull(wavURL: fullAudioURL!) : []
        
        // Process tones in parallel
        try await withThrowingTaskGroup(of: (TimeInterval, String).self) { group in
            for segment in audioSegments {
                group.addTask {
                    let tone = await toneAnalyzer.analyze(wavURL: segment.wavURL).description
                    return (segment.timestamp, tone)
                }
            }
            for try await result in group {
                let segmentStart = result.0
                let segmentEnd = segmentStart + 3.0
                
                let matchedTexts = fullTranscripts.filter { t in 
                    max(t.start, segmentStart) < min(t.end, segmentEnd)
                }.map { $0.text }
                
                let transcript = matchedTexts.joined(separator: " ")
                audioResults[segmentStart] = (transcript, result.1)
            }
        }
        
        // 4. Process Video Frames
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
                        let audioInfo = audioResults[timestamp] ?? ("", "silent")
                        
                        if frame.isDuplicateOfPrevious {
                            print("[\(Date().formatted(date: .omitted, time: .standard))]      ⚡️ Skipped ML for duplicate frame at \(timestamp)s")
                            return (
                                timestamp: timestamp,
                                matches: [],
                                thumbnail: nil,
                                bottomCropThumbnail: nil,
                                audioTranscript: audioInfo.transcript,
                                audioTone: audioInfo.tone,
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
                        
                        // Format the text summary for this specific frame
                        let contentSummary = ScreenContentSummaryBuilder.segmentSummary(
                            label: clip.categories.first?.label ?? "Unknown",
                            onScreenText: vision.onScreenText,
                            sceneHints: vision.sceneHints,
                            transcript: audioInfo.transcript,
                            audioTone: audioInfo.tone
                        )
                        
                        return (
                            timestamp: timestamp,
                            matches: clip.categories,
                            thumbnail: nil, 
                            bottomCropThumbnail: nil,
                            audioTranscript: audioInfo.transcript,
                            audioTone: audioInfo.tone,
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
            }
        }
        
        if !frameBatch.isEmpty {
            let results = try await processBatch(frameBatch)
            rawFrames.append(contentsOf: results)
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
            }
        }
        
        // 5. Aggregate Timeline (Fuse Audio and Video mathematically)
        print("[\(Date().formatted(date: .omitted, time: .standard))] ⏱️ Step 5: Aggregating timeline (Fusion)...")
        let timeline = await aggregator.timeline(frames: rawFrames, fps: 1.0, intervalSeconds: 3)
        
        // 6. Generate the Final AI Summary
        print("[\(Date().formatted(date: .omitted, time: .standard))] 🧠 Step 6: Generating AI Summary...")
        let dominantCategory = timeline.first?.label ?? "Mixed content"
        let aiProseSummary = try await summarizer.summarizeRecording(
            timeline: timeline,
            overallCategory: dominantCategory,
            child: child
        )
        
        // 7. Extract Top Creators
        print("[\(Date().formatted(date: .omitted, time: .standard))] 👤 Step 7: Extracting top creators...")
        let allHandles = rawFrames.compactMap { $0.creatorHandle }
        let handleCounts = Dictionary(allHandles.map { ($0, Int(1)) }, uniquingKeysWith: +)
        let topCreators = handleCounts.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
        
        // 8. Generate Guidance
        print("[\(Date().formatted(date: .omitted, time: .standard))] 💡 Step 8: Generating insights and guidance...")
        let guidanceEngine = GuidanceEngine()
        let insights = await guidanceEngine.generateInsights(
            timeline: timeline, 
            dominantCategory: dominantCategory,
            child: child
        )
        
        var concernSignals = insights.signals
        let fullTranscriptString = fullTranscripts.map { $0.text }.joined(separator: " ")
        let sentimentResult = await sentimentAnalyzer.analyze(transcript: fullTranscriptString)
        if sentimentResult.isHighlyNegative {
            concernSignals.append(ConcernSignal(
                title: "Negative Sentiment",
                description: "Highly negative sentiment detected in the spoken audio.",
                severity: .high
            ))
        }
        
        // 9. Return the beautiful result to the UI!
        print("[\(Date().formatted(date: .omitted, time: .standard))] ✅ Pipeline complete! Returning results.")
        return SessionAnalysisResult(
            dominantCategory: ClassificationCategory(name: dominantCategory, prompts: []), 
            aiProseSummary: aiProseSummary,
            topCreatorsSeen: topCreators,
            concernSignals: concernSignals,
            guidance: insights.guidance,
            timeline: timeline
        )
    }
}