//
//  SessionHistoryDetailView.swift
//  team-10-c3
//

import SwiftUI

struct SessionHistoryDetailView: View {
    let entry: SessionHistoryEntry
    let sessionAnalysisStore: SessionAnalysisStore?

    @State private var showScreenBreakdown = false
    @State private var result: PipelineResult?
    @State private var isLoadingResult = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                header

                if let errorMessage = entry.errorMessage {
                    SessionResultCard(
                        icon: "exclamationmark.triangle.fill",
                        iconColor: .orange,
                        title: "Analysis unavailable",
                        content: errorMessage
                    )
                }

                if isLoadingResult {
                    ProgressView("Loading session analysis…")
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if let result {
                    SessionResultCard(
                        icon: "chart.bar.fill",
                        iconColor: .decorativeSkyBlue,
                        title: "Dominant Category",
                        content: result.dominantCategoryDisplay
                    )

                    SessionResultCard(
                        icon: "text.alignleft",
                        iconColor: .primaryMediumBlue,
                        title: "AI Summary",
                        content: result.summary
                    )

                    if let transcript = result.sessionTranscriptForDisplay,
                       TranscriptSanitizer.isMeaningful(transcript) {
                        SessionResultCard(
                            icon: "waveform",
                            iconColor: .primaryMediumBlue,
                            title: "What we heard (session)",
                            content: transcript
                        )
                    }

                    SessionResultCard(
                        icon: "leaf.fill",
                        iconColor: .decorativeMintGreen,
                        title: "Offline Activity",
                        content: result.offlineActivity
                    )

                    if !result.screens.isEmpty {
                        SecondaryButton(
                            title: "View screen-by-screen breakdown (\(result.screens.count))",
                            size: .large,
                            systemImage: "rectangle.stack"
                        ) {
                            showScreenBreakdown = true
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    SessionResultCard(
                        icon: "exclamationmark.triangle.fill",
                        iconColor: .orange,
                        title: "Analysis unavailable",
                        content: "This session's detailed analysis is not available."
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(Color.uiBackground.ignoresSafeArea())
        .foregroundStyle(.textPrimary)
        .navigationTitle(entry.dateLabel)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showScreenBreakdown) {
            if let screens = result?.screens {
                SessionScreenBreakdownView(screens: screens)
            }
        }
        .task {
            guard result == nil, entry.errorMessage == nil else { return }
            isLoadingResult = true
            result = sessionAnalysisStore?.loadResult(sessionId: entry.sessionId)
            isLoadingResult = false
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.timeLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let category = entry.categoryLabel {
                Text(category)
                    .font(.system(size: 22, weight: .bold))
            } else {
                Text("Session Analysis")
                    .font(.system(size: 22, weight: .bold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
