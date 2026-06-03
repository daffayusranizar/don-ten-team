//
//  SessionAnalysisProgress.swift
//  team-10-c3
//

import Foundation

/// Parent-facing progress while a recorded session is analyzed.
public struct SessionAnalysisProgress: Equatable, Sendable {
    public enum Phase: Int, CaseIterable, Sendable {
        case waitingForRecording
        case loadingRecording
        case preparingModels
        case extractingAudio
        case transcribing
        case analyzingScreens
        case generatingSummary
        case finalizing

        public var title: String {
            switch self {
            case .waitingForRecording:
                return "Waiting for recording"
            case .loadingRecording:
                return "Loading recording"
            case .preparingModels:
                return "Preparing analysis"
            case .extractingAudio:
                return "Extracting audio"
            case .transcribing:
                return "Transcribing speech"
            case .analyzingScreens:
                return "Analyzing screens"
            case .generatingSummary:
                return "Writing summary"
            case .finalizing:
                return "Finishing up"
            }
        }
    }

    public let phase: Phase
    /// 0...1 for the overall analysis flow.
    public let fraction: Double
    public let detail: String?

    public init(phase: Phase, fraction: Double, detail: String?) {
        self.phase = phase
        self.fraction = fraction
        self.detail = detail
    }

    public static let initial = SessionAnalysisProgress(
        phase: .waitingForRecording,
        fraction: 0,
        detail: "Saving your screen recording…"
    )

    public var percentText: String {
        "\(Int((fraction * 100).rounded()))%"
    }

    public func status(for step: Phase) -> StepStatus {
        if step.rawValue < phase.rawValue {
            return .completed
        }
        if step == phase {
            return .current
        }
        return .upcoming
    }

    public enum StepStatus: Sendable {
        case completed
        case current
        case upcoming
    }
}

public typealias SessionAnalysisProgressHandler = @Sendable (SessionAnalysisProgress) -> Void
