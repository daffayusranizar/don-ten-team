import Foundation

struct TranscriptFusionSegment: Sendable {
    let id: Int
    let timestamp: TimeInterval
    let audioText: String?
    let visualText: String?
}

actor TranscriptFusionAnalyzer {
    init() {}

    func fuse(segments: [TranscriptFusionSegment]) -> TranscriptFusionResult {
        var narratives: [String] = []
        var audioDominant = 0
        var visualFallback = 0
        var dropped = 0

        for segment in segments.sorted(by: { $0.timestamp < $1.timestamp }) {
            let audio = TranscriptSanitizer.meaningfulForStorage(segment.audioText ?? "")
            let visual = TranscriptSanitizer.meaningfulForStorage(segment.visualText ?? "")

            if let audio, let visual {
                // Audio wins when both are present and potentially conflicting.
                let line = "Audio: \(audio). On-screen: \(visual)."
                narratives.append(line)
                audioDominant += 1
                continue
            }
            if let audio {
                narratives.append("Audio: \(audio).")
                audioDominant += 1
                continue
            }
            if let visual {
                narratives.append("On-screen: \(visual).")
                visualFallback += 1
                continue
            }
            dropped += 1
        }

        let digest = narratives.joined(separator: " ")
        let digestValue = TranscriptSanitizer.meaningfulForStorage(digest)
        let brief = digestValue.flatMap { TranscriptDigestBuilder.buildBriefSummary(fullTrackText: nil, digest: $0) }
        let evidence = buildEvidenceBlock(from: narratives)

        return TranscriptFusionResult(
            fusedSegmentNarratives: narratives,
            sessionDigest: digestValue,
            sessionBrief: brief,
            summaryEvidence: evidence,
            fusionStats: TranscriptFusionStats(
                audioDominantSegments: audioDominant,
                visualFallbackSegments: visualFallback,
                droppedSegments: dropped
            )
        )
    }

    private func buildEvidenceBlock(from narratives: [String]) -> String? {
        guard !narratives.isEmpty else { return nil }
        return narratives
            .prefix(12)
            .enumerated()
            .map { idx, line in "\(idx + 1). \(line)" }
            .joined(separator: "\n")
    }
}
