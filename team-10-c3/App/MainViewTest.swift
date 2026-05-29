//
//  MainViewTest.swift
//  team-10-c3
//
//  Created by Daffa Yuranizar Arrifi on 26/05/26.
//

import SwiftUI

struct MainViewTest: View {
    @State private var isRunning = false
    @State private var result: PipelineResult? = nil
    @State private var errorMessage: String? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                // MARK: - Header
                Text("🧠 ParentingEngine Test")
                    .font(.title2.bold())
                    .padding(.top)

                // MARK: - Button
                Button {
                    runPipeline()
                } label: {
                    HStack {
                        if isRunning {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isRunning ? "Analyzing..." : "Test AI Backend")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isRunning ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isRunning)
                .padding(.horizontal)

                // MARK: - Error
                if let error = errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Pipeline Failed", systemImage: "xmark.circle.fill")
                            .font(.headline)
                            .foregroundColor(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                // MARK: - Results
                if let result = result {
                    VStack(spacing: 16) {

                        // Category
                        ResultCard(
                            icon: "📊",
                            title: "Dominant Category",
                            value: result.category
                        )

                        // AI Summary
                        ResultCard(
                            icon: "✍️",
                            title: "AI Summary",
                            value: result.summary
                        )

                        // Top Creators
                        if !result.creators.isEmpty {
                            ResultCard(
                                icon: "🎥",
                                title: "Creators Seen",
                                value: result.creators.joined(separator: ", ")
                            )
                        }

                        // Concern Signals
                        if !result.signals.isEmpty {
                            ResultCard(
                                icon: "⚠️",
                                title: "Concern Signals",
                                value: result.signals.joined(separator: "\n")
                            )
                        }

                        // Guidance
                        ResultCard(
                            icon: "💡",
                            title: "Conversation Starter",
                            value: result.conversationStarter
                        )
                        ResultCard(
                            icon: "🌿",
                            title: "Offline Activity",
                            value: result.offlineActivity
                        )
                    

                        // Timeline
                        VStack(alignment: .leading, spacing: 8) {
                            Text("🎞️ Timeline (\(result.timelineItems.count) segments)")
                                .font(.headline)
                                .padding(.horizontal)
                            ForEach(result.timelineItems, id: \.timestamp) { item in
                                HStack(alignment: .top) {
                                    Text(item.timestamp)
                                        .font(.caption.monospacedDigit())
                                        .foregroundColor(.secondary)
                                        .frame(width: 44, alignment: .leading)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.label)
                                            .font(.caption.bold())
                                        if let summary = item.summary {
                                            Text(summary)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    .onAppear {
                        print("""
                        === AI Result ===
                        Category: \(result.category)
                        AI Summary: \(result.summary)
                        Creators Seen: \(result.creators.isEmpty ? "None" : result.creators.joined(separator: ", "))
                        Concern Signals:
                        \(result.signals.isEmpty ? "None" : result.signals.joined(separator: "\n"))
                        Conversation Starter: \(result.conversationStarter)
                        Offline Activity: \(result.offlineActivity)
                        """)
                    }
                }

                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - Pipeline Runner

    private func runPipeline() {
        guard let bundleURL = Bundle.main.url(forResource: "video_test_record_attemp_3", withExtension: "MP4") else {
            errorMessage = "video_test.mp4 not found in bundle!"
            return
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_movie.mp4")
        try? FileManager.default.removeItem(at: tempURL)
        try? FileManager.default.copyItem(at: bundleURL, to: tempURL)

        isRunning = true
        result = nil
        errorMessage = nil

        Task {
            do {
                let orchestrator = PipelineOrchestrator()
                let output = try await orchestrator.processSession(videoURL: tempURL)

                await MainActor.run {
                    self.result = PipelineResult(from: output)
                    self.isRunning = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isRunning = false
                }
            }
        }
    }
}

// MARK: - View Model

struct PipelineResult {
    let category: String
    let summary: String
    let creators: [String]
    let signals: [String]
    let conversationStarter: String
    let offlineActivity: String
    let timelineItems: [TimelineItem]

    struct TimelineItem {
        let timestamp: String
        let label: String
        let summary: String?
    }

    init(from result: SessionAnalysisResult) {
        self.category = result.dominantCategory.name
        self.summary = result.aiProseSummary
        self.creators = result.topCreatorsSeen
        self.signals = result.concernSignals.map { "[\($0.severity)] \($0.title): \($0.description)" }
        self.conversationStarter = result.guidance.conversationStarters.first ?? "—"
        self.offlineActivity = result.guidance.offlineActivity
        self.timelineItems = result.timeline.map { frame in
            let mins = Int(frame.timestamp) / 60
            let secs = Int(frame.timestamp) % 60
            return TimelineItem(
                timestamp: String(format: "%d:%02d", mins, secs),
                label: frame.label,
                summary: frame.contentSummary
            )
        }
    }
}

// MARK: - Reusable Card

struct ResultCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(icon) \(title)")
                .font(.headline)
            Text(value)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}
