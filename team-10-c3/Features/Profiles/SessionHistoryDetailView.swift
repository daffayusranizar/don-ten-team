//
//  SessionHistoryDetailView.swift
//  team-10-c3
//

import SwiftUI

struct SessionHistoryDetailView: View {
    let entry: SessionHistoryEntry

    @State private var showScreenBreakdown = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                header

                if let errorMessage = entry.errorMessage, entry.result == nil {
                    SessionResultCard(
                        icon: "exclamationmark.triangle.fill",
                        iconColor: .orange,
                        title: "Analysis unavailable",
                        content: errorMessage
                    )
                }

                if let result = entry.result {
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

                    if !result.conversationStarters.isEmpty {
                        SessionResultCard(
                            icon: "bubble.left.and.bubble.right.fill",
                            iconColor: .decorativeLavender,
                            title: "Conversation Starters",
                            content: result.conversationStarters.joined(separator: "\n\n")
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
            if let screens = entry.result?.screens {
                SessionScreenBreakdownView(screens: screens)
            }
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
