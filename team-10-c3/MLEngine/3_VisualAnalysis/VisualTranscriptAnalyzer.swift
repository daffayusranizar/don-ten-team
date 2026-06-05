import Foundation

struct VisualTranscriptCandidate: Sendable {
    let segmentKey: Int
    let timestamp: TimeInterval
    let text: String
}

actor VisualTranscriptAnalyzer {
    private let window: TranscriptAnalysisWindow

    init(window: TranscriptAnalysisWindow = .defaultPhase2) {
        self.window = window
    }

    func analyze(
        candidates: [VisualTranscriptCandidate],
        totalDuration: TimeInterval
    ) -> VisualTranscriptAnalysisResult {
        var segmentVisualText: [Int: String] = [:]
        var usefulCount = 0
        var droppedCount = 0

        for candidate in candidates {
            guard window.contains(candidate.timestamp, in: totalDuration) else {
                droppedCount += 1
                continue
            }
            let cleaned = candidate.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard OnScreenTextSanitizer.isUsefulOnScreenContent(cleaned) else {
                droppedCount += 1
                continue
            }
            usefulCount += 1
            if let existing = segmentVisualText[candidate.segmentKey], existing.count >= cleaned.count {
                continue
            }
            segmentVisualText[candidate.segmentKey] = cleaned
        }

        return VisualTranscriptAnalysisResult(
            segmentVisualText: segmentVisualText,
            usefulSegmentCount: usefulCount,
            lowSignalDropCount: droppedCount
        )
    }
}
