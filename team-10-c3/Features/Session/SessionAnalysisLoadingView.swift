//
//  SessionAnalysisLoadingView.swift
//  team-10-c3
//

import SwiftUI

struct SessionAnalysisLoadingView: View {
    let progress: SessionAnalysisProgress
    let onSkip: () -> Void

    private let visibleSteps: [SessionAnalysisProgress.Phase] = [
        .waitingForRecording,
        .loadingRecording,
        .preparingModels,
        .extractingAudio,
        .transcribing,
        .analyzingScreens,
        .generatingSummary,
        .finalizing
    ]

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 10) {
                Image(systemName: "waveform.badge.magnifyingglass")
                    .font(.system(size: 44))
                    .foregroundStyle(.primaryMediumBlue)
                    .symbolEffect(.pulse, options: .repeating)

                Text("Analyzing session")
                    .font(.system(size: 24, weight: .bold))

                Text(progress.phase.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primaryMediumBlue)

                if let detail = progress.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }

            VStack(spacing: 8) {
                ProgressView(value: progress.fraction)
                    .tint(.primaryMediumBlue)

                Text(progress.percentText)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(visibleSteps, id: \.rawValue) { step in
                    stepRow(step: step, status: progress.status(for: step))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.uiSurface, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 24)

            SecondaryButton(title: "Skip analysis", size: .medium, action: onSkip)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
    }

    @ViewBuilder
    private func stepRow(step: SessionAnalysisProgress.Phase, status: SessionAnalysisProgress.StepStatus) -> some View {
        HStack(spacing: 12) {
            stepIcon(status: status)
                .frame(width: 22)

            Text(step.title)
                .font(.system(size: 14, weight: status == .current ? .semibold : .regular))
                .foregroundStyle(status == .upcoming ? Color.secondary : Color.textPrimary)

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func stepIcon(status: SessionAnalysisProgress.StepStatus) -> some View {
        switch status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.decorativeMintGreen)
        case .current:
            ProgressView()
                .controlSize(.small)
        case .upcoming:
            Image(systemName: "circle")
                .foregroundStyle(.secondary.opacity(0.5))
        }
    }
}

#Preview {
    SessionAnalysisLoadingView(
        progress: SessionAnalysisProgress(
            phase: .analyzingScreens,
            fraction: 0.52,
            detail: "Screen 4 of 12"
        ),
        onSkip: {}
    )
    .background(Color.uiBackground)
}
