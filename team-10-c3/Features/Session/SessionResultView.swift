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
    @Environment(\.kidSessionViewModel) private var kidSessionViewModel
    let onStartNew: () -> Void

    @State private var showScreenBreakdown = false
    @State private var breakdownScreens: [ScreenBreakdownItem] = []

    private var showsRecordingHint: Bool {
        !kidSessionViewModel.sessionIncludedScreenRecording
    }

    var body: some View {
        @Bindable var viewModel = kidSessionViewModel

        Group {
            if viewModel.isAnalyzingSession {
                analyzingContent(viewModel: viewModel)
            } else {
                resultsScrollContent(
                    result: viewModel.sessionAnalysisResult,
                    errorMessage: viewModel.sessionAnalysisError
                )
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .background(Color.uiBackground.ignoresSafeArea())
        .foregroundStyle(.textPrimary)
        .navigationDestination(isPresented: $showScreenBreakdown) {
            SessionScreenBreakdownView(screens: breakdownScreens)
        }
    }

    @ViewBuilder
    private func analyzingContent(viewModel: KidSessionViewModel) -> some View {
        SessionAnalysisLoadingView(
            progress: viewModel.analysisProgress,
            onSkip: { viewModel.cancelSessionAnalysis() }
        )
    }

    private func resultsScrollContent(
        result: PipelineResult?,
        errorMessage: String?
    ) -> some View {
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

                if showsRecordingHint, result == nil, errorMessage == nil {
                    SessionResultCard(
                        icon: "record.circle",
                        iconColor: .primaryMediumBlue,
                        title: "No session analysis",
                        content: "Turn on \"Record your screen\" before starting the next session to get AI insights from the broadcast recording."
                    )
                }

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

                    if !result.screens.isEmpty {
                        SecondaryButton(
                            title: "View screen-by-screen breakdown (\(result.screens.count))",
                            size: .large,
                            systemImage: "rectangle.stack"
                        ) {
                            breakdownScreens = result.screens
                            showScreenBreakdown = true
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                // Start new session button
                PrimaryButton(title: "Start New Session", size: .large, action: onStartNew)
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
        }
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

#Preview("With breakdown") {
    let coordinator = SessionCoordinator(
        sessionRepository: InMemorySessionRepository(),
        screenTimeService: ScreenTimeService(),
        familyControlsAuth: PreviewFamilyControlsAuthService()
    )
    let vm = KidSessionViewModel(sessionCoordinator: coordinator)
    vm.sessionAnalysisResult = PipelineResult(
        category: "Educational",
        summary: "Mostly learning content.",
        creators: ["@Example"],
        signals: [],
        conversationStarter: "What did you learn?",
        offlineActivity: "Draw what you learned.",
        screens: [.preview]
    )
    return NavigationStack {
        SessionResultView(onStartNew: {})
            .environment(\.kidSessionViewModel, vm)
    }
}
