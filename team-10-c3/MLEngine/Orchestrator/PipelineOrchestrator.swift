import Foundation
import UIKit

public actor PipelineOrchestrator {
    public init() {}
    
    /// The main entry point for the UI team to call
    public func processSession(videoURL: URL) async throws -> SessionAnalysisResult {
        // 1. Boot up the engines (This happens in the background)
        let frameExtractor = ScreenRecordingFrameExtractor()
        let audioExtractor = ScreenRecordingAudioExtractor()
        let aggregator = ScreenRecordingAggregator()
        let summarizer = LLMSummarizer()
        
        let clipClassifier = try await MobileCLIPClassifier()
        let whisper = try await ScreenRecordingWhisperTranscriber()
        let toneAnalyzer = ScreenRecordingAudioToneAnalyzer()
        let visionAnalyzer = VisionFrameContentAnalyzer()
        let handleExtractor = CreatorHandleExtractor()
        
        // 2. Extract Audio First (It's faster)
        let audioSegments = try await audioExtractor.exportClassificationWindows(from: videoURL)
        
        // 3. Process Audio (Transcript and Tone)
        var audioResults: [TimeInterval: (transcript: String, tone: String)] = [:]
        for segment in audioSegments {
            let transcript = try await whisper.transcribe(wavURL: segment.wavURL)
            let tone = await toneAnalyzer.analyze(wavURL: segment.wavURL).description
            audioResults[segment.timestamp] = (transcript, tone)
        }
        
        // 4. Process Video Frames (One by one to save memory!)
        var rawFrames: [(
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
        )] = []
        
        try await frameExtractor.forEachFrame(from: videoURL) { frame in
            let timestamp = frame.timestamp
            let audioInfo = audioResults[timestamp] ?? ("", "silent")
            
            // Run Vision & CoreML in parallel for this exact frame
            async let visionAnalysis = visionAnalyzer.analyze(pixelBuffer: frame.pixelBuffer)
            async let handleAnalysis = handleExtractor.extract(from: frame.pixelBuffer)
            async let clipAnalysis = clipClassifier.classify(
                pixelBuffer: frame.pixelBuffer,
                temperature: 100,
                topK: 5
            )
            
            // Await them all finishing
            let vision = await visionAnalysis
            let handle = await handleAnalysis
            let clip = try await clipAnalysis
            
            // Format the text summary for this specific frame
            let contentSummary = ScreenContentSummaryBuilder.segmentSummary(
                label: clip.categories.first?.label ?? "Unknown",
                onScreenText: vision.onScreenText,
                sceneHints: vision.sceneHints,
                transcript: audioInfo.transcript,
                audioTone: audioInfo.tone
            )
            
            // Save the results
            rawFrames.append((
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
                creatorHandle: handle.handle
            ))
        }
        
        // 5. Aggregate Timeline (Fuse Audio and Video mathematically)
        let timeline = await aggregator.timeline(frames: rawFrames, fps: 1.0, intervalSeconds: 3)
        
        // 6. Generate the Final AI Summary
        let dominantCategory = timeline.first?.label ?? "Mixed content"
        let aiProseSummary = try await summarizer.summarizeRecording(
            timeline: timeline,
            overallCategory: dominantCategory
        )
        
        // 7. Extract Top Creators
        let allHandles = rawFrames.compactMap { $0.creatorHandle }
        let handleCounts = Dictionary(allHandles.map { ($0, Int(1)) }, uniquingKeysWith: +)
        let topCreators = handleCounts.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
        
        // 8. Generate Guidance
        let guidanceEngine = GuidanceEngine()
        let insights = await guidanceEngine.generateInsights(
            timeline: timeline, 
            dominantCategory: dominantCategory
        )
        
        // 9. Return the beautiful result to the UI!
        return SessionAnalysisResult(
            dominantCategory: ClassificationCategory(name: dominantCategory, prompts: []), 
            aiProseSummary: aiProseSummary,
            topCreatorsSeen: topCreators,
            concernSignals: insights.signals,
            guidance: insights.guidance,
            timeline: timeline
        )
    }
}