import Foundation

struct TranscriptAnalysisWindow: Sendable {
    let skipStartSeconds: TimeInterval
    let skipEndSeconds: TimeInterval

    static let defaultPhase2 = TranscriptAnalysisWindow(
        skipStartSeconds: 6,
        skipEndSeconds: 4
    )

    func contains(_ timestamp: TimeInterval, in totalDuration: TimeInterval) -> Bool {
        guard totalDuration > 0 else { return true }
        let clamped = max(0, timestamp)
        let upperBound = max(0, totalDuration - skipEndSeconds)
        return clamped >= skipStartSeconds && clamped <= upperBound
    }
}

struct AudioTranscriptAnalysisResult: Sendable {
    let bucketedTranscripts: [Int: String]
    let fullTrackSegments: [SegmentedTranscript]
    let coverage: Double
    let usedFallbackWindows: Bool
    let hasAudioTrack: Bool
    let analyzedDuration: TimeInterval
}

struct VisualTranscriptAnalysisResult: Sendable {
    let segmentVisualText: [Int: String]
    let usefulSegmentCount: Int
    let lowSignalDropCount: Int
}

struct TranscriptFusionStats: Sendable {
    let audioDominantSegments: Int
    let visualFallbackSegments: Int
    let droppedSegments: Int
}

struct TranscriptFusionResult: Sendable {
    let fusedSegmentNarratives: [String]
    let sessionDigest: String?
    let sessionBrief: String?
    let summaryEvidence: String?
    let fusionStats: TranscriptFusionStats
}
