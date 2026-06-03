//
//  SessionResultView.swift
//  team-10-c3
//
//  Created after session analysis completes.
//  Shows the AI pipeline result with a new result card design.
//

import SwiftUI

// MARK: - Session Result View

struct SessionResultView: View {
    let result: PipelineResult?
    let errorMessage: String?
    let onStartNew: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.primaryMediumBlue)

                    Text("Session Complete")
                        .font(.system(size: 26, weight: .bold))

                    Text("Here's what we found")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
                .padding(.bottom, 8)

                // Error state
                if let error = errorMessage {
                    SessionResultCard(
                        icon: "exclamationmark.triangle.fill",
                        iconColor: .orange,
                        title: "Something went wrong",
                        content: error
                    )
                }

                // Results
                if let result {
                    SessionResultCard(
                        icon: "chart.bar.fill",
                        iconColor: .decorativeSkyBlue,
                        title: "Dominant Category",
                        content: result.category
                    )

                    SessionResultCard(
                        icon: "text.alignleft",
                        iconColor: .primaryMediumBlue,
                        title: "AI Summary",
                        content: result.summary
                    )

                    if !result.creators.isEmpty {
                        SessionResultCard(
                            icon: "person.wave.2.fill",
                            iconColor: .decorativeMintGreen,
                            title: "Creators Seen",
                            content: result.creators.joined(separator: ", ")
                        )
                    }

                    if !result.signals.isEmpty {
                        SessionResultCard(
                            icon: "exclamationmark.circle.fill",
                            iconColor: .decorativeCoralPink,
                            title: "Concern Signals",
                            content: result.signals.joined(separator: "\n")
                        )
                    }

                    SessionResultCard(
                        icon: "bubble.left.and.bubble.right.fill",
                        iconColor: .decorativeSunnyYellow,
                        title: "Conversation Starter",
                        content: result.conversationStarter
                    )

                    SessionResultCard(
                        icon: "leaf.fill",
                        iconColor: .decorativeMintGreen,
                        title: "Offline Activity",
                        content: result.offlineActivity
                    )
                }

                // Start new session button
                PrimaryButton(title: "Start New Session", size: .large, action: onStartNew)
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .background(Color.uiBackground.ignoresSafeArea())
        .foregroundStyle(.textPrimary)
    }
}

// MARK: - Session Result Card

struct SessionResultCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Card header
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 32, height: 32)
                    .background(iconColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }

            // Content
            Text(content)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.uiSurface, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SessionResultView(
            result: nil,
            errorMessage: "Preview: No recording file found."
        ) {}
    }
}
