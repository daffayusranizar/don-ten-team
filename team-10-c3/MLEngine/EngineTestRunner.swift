//
//  EngineTestRunner.swift
//  team-10-c3
//
//  Created by Daffa Yuranizar Arrifi on 26/05/26.
//

import Foundation
import UIKit

@MainActor
public class EngineTestRunner {
    public static func testPipeline(with videoURL: URL) {
        print("🚀 Starting ParentingEngine Backend Pipeline...")
        print("📂 Video URL: \(videoURL.path)")
        print("📂 File exists: \(FileManager.default.fileExists(atPath: videoURL.path))")
        
        Task {
            do {
                print("⚙️ Step 1: Initializing actors...")
                let frameExtractor = ScreenRecordingFrameExtractor()
                let audioExtractor = ScreenRecordingAudioExtractor()
                let aggregator = ScreenRecordingAggregator()
                print("✅ Basic actors ready")

                print("⚙️ Step 2: Loading MobileCLIP models...")
                let clipClassifier = try await MobileCLIPClassifier()
                print("✅ MobileCLIP loaded")

                print("⚙️ Step 3: Loading Whisper model...")
                let whisper = try await ScreenRecordingWhisperTranscriber()
                print("✅ Whisper loaded")

                print("⚙️ Step 4: Creating summarizer...")
                let summarizer = LLMSummarizer()
                print("✅ All actors ready")

                print("⚙️ Step 5: Extracting audio windows...")
                let audioSegments = try await audioExtractor.exportClassificationWindows(from: videoURL)
                print("✅ Audio segments extracted: \(audioSegments.count)")

                print("⚙️ Step 6: Extracting video frames...")
                var frameCount = 0
                try await frameExtractor.forEachFrame(from: videoURL) { frame in
                    frameCount += 1
                    print("   🎞️ Frame \(frame.index) at \(String(format: "%.1f", frame.timestamp))s")
                }
                print("✅ Video frames processed: \(frameCount)")

                print("✅ PIPELINE COMPLETED SUCCESSFULLY!")

            } catch {
                print("❌ PIPELINE FAILED at step above: \(error)")
                print("❌ Error type: \(type(of: error))")
                print("❌ Full error: \(error.localizedDescription)")
            }
        }
    }
}
