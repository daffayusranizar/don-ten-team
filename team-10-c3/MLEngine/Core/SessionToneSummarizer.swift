//
//  SessionToneSummarizer.swift
//  team-10-c3
//

import Foundation

public enum SessionToneConfidence: String, Codable, Sendable, Equatable {
    case low
    case medium
    case high
}

public struct SessionToneSummary: Codable, Equatable, Sendable {
    public let parentFacingSummary: String
    public let confidence: SessionToneConfidence

    public init(parentFacingSummary: String, confidence: SessionToneConfidence) {
        self.parentFacingSummary = parentFacingSummary
        self.confidence = confidence
    }
}

/// Aggregates per-frame acoustic tone into one parent-facing session verdict with confidence gating.
public enum SessionToneSummarizer {
    private struct FrameSignals {
        let isSilent: Bool
        let hasTranscript: Bool
        let pace: PaceBucket
        let energy: EnergyBucket
        let character: CharacterBucket
        let inferredOnly: Bool
    }

    private enum PaceBucket: String {
        case slow, normal, fast, unknown
    }

    private enum EnergyBucket: String {
        case quiet, calm, moderate, energetic, silent, unknown
    }

    private enum CharacterBucket: String {
        case spoken, music, speechOverMusic, ambient, silent, unknown
    }

    public static func summarize(timeline: [FrameClassificationSummary]) -> SessionToneSummary {
        let signals = timeline.map { frameSignals(from: $0.audioTone, transcript: $0.audioTranscript) }
        return rollup(signals)
    }

    static func summarize(screens: [StoredScreenBreakdown]) -> SessionToneSummary {
        let signals = screens.map { frameSignals(from: $0.audioTone, transcript: $0.audioTranscript) }
        return rollup(signals)
    }

    static func summarize(screens: [ScreenBreakdownItem]) -> SessionToneSummary {
        let signals = screens.map { frameSignals(from: $0.audioTone, transcript: $0.audioTranscript) }
        return rollup(signals)
    }

    /// One-line parent-facing tone for a single ~3s breakdown row.
    static func frameDisplayTone(audioTone: String?, transcript: String?) -> String? {
        let signals = frameSignals(from: audioTone, transcript: transcript)
        if signals.isSilent {
            return nil
        }
        return parentCopy(
            pace: signals.pace == .unknown ? nil : signals.pace,
            energy: signals.energy == .unknown ? nil : signals.energy,
            character: signals.character == .unknown ? nil : signals.character,
            transcriptRatio: signals.hasTranscript ? 1 : 0,
            confidence: .high
        )
    }

    /// Weekly rollup across multiple sessions (majority of non-low-confidence summaries).
    public static func weeklyVerdict(from summaries: [SessionToneSummary]) -> String? {
        let usable = summaries.filter { $0.confidence != .low }
        guard !usable.isEmpty else { return nil }
        let fastCount = usable.filter { $0.parentFacingSummary.lowercased().contains("fast-paced") }.count
        let calmCount = usable.filter { $0.parentFacingSummary.lowercased().contains("calm") }.count
        let musicCount = usable.filter { $0.parentFacingSummary.lowercased().contains("music") }.count

        if fastCount > usable.count / 2 {
            return "This week, sessions tended to sound fast-paced and high-energy."
        }
        if calmCount > usable.count / 2 {
            return "This week, sessions tended to sound calm and conversational."
        }
        if musicCount > usable.count / 2 {
            return "This week, sessions often had music-forward audio."
        }
        return usable.first?.parentFacingSummary
    }

    // MARK: - Rollup

    private static func rollup(_ signals: [FrameSignals]) -> SessionToneSummary {
        guard !signals.isEmpty else {
            return SessionToneSummary(
                parentFacingSummary: "App audio wasn't clear enough to judge tone for this session.",
                confidence: .low
            )
        }

        let total = signals.count
        let silentCount = signals.filter(\.isSilent).count
        let transcriptCount = signals.filter(\.hasTranscript).count
        let audibleCount = total - silentCount

        if silentCount > total / 2 {
            return SessionToneSummary(
                parentFacingSummary: "App audio wasn't clear enough to judge tone for this session.",
                confidence: .low
            )
        }

        let transcriptRatio = Float(transcriptCount) / Float(total)
        let paceBuckets = signals.map(\.pace).filter { $0 != .unknown }
        let majorityPace = majority(paceBuckets)

        let energyBuckets = signals.filter { !$0.isSilent }.map(\.energy)
        let majorityEnergy = majority(energyBuckets)

        let characterBuckets = signals.filter { !$0.isSilent }.map(\.character)
        let majorityCharacter = majority(characterBuckets)

        let inferredRatio = Float(signals.filter(\.inferredOnly).count) / Float(total)

        var confidence: SessionToneConfidence
        if audibleCount >= total * 2 / 3, transcriptRatio >= 0.3, inferredRatio < 0.5 {
            confidence = .high
        } else if audibleCount >= total / 3 {
            confidence = .medium
        } else {
            confidence = .low
        }

        let summary = parentCopy(
            pace: majorityPace,
            energy: majorityEnergy,
            character: majorityCharacter,
            transcriptRatio: transcriptRatio,
            confidence: confidence
        )

        if confidence == .low {
            return SessionToneSummary(
                parentFacingSummary: "App audio wasn't clear enough to judge tone for this session.",
                confidence: .low
            )
        }

        return SessionToneSummary(parentFacingSummary: summary, confidence: confidence)
    }

    private static func parentCopy(
        pace: PaceBucket?,
        energy: EnergyBucket?,
        character: CharacterBucket?,
        transcriptRatio: Float,
        confidence: SessionToneConfidence
    ) -> String {
        let qualifier = confidence == .medium ? ", based on limited audio" : ""

        if pace == .fast, transcriptRatio >= 0.3 {
            return "Much of this session sounded fast-paced and high-energy\(qualifier)."
        }

        if character == .music || character == .speechOverMusic {
            return "Music or background audio was common throughout this session\(qualifier)."
        }

        if (energy == .calm || energy == .quiet), pace == .slow || pace == .normal {
            return "Audio was mostly calm and conversational\(qualifier)."
        }

        if energy == .energetic {
            return "Audio was often energetic or loud\(qualifier)."
        }

        if pace == .normal || pace == .slow {
            return "Audio was mostly calm and conversational\(qualifier)."
        }

        return "Audio patterns were mixed across this session\(qualifier)."
    }

    // MARK: - Parsing

    private static func frameSignals(from audioTone: String?, transcript: String?) -> FrameSignals {
        let tone = audioTone?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let hasTranscript = TranscriptSanitizer.meaningfulForStorage(transcript ?? "") != nil
        let isSilent = tone.isEmpty || AudioToneLabels.isSilentDescription(tone)

        let inferredOnly = isSilent && hasTranscript
            || tone.contains("inferred from screen")

        return FrameSignals(
            isSilent: isSilent && !hasTranscript,
            hasTranscript: hasTranscript,
            pace: paceBucket(from: tone, hasTranscript: hasTranscript),
            energy: energyBucket(from: tone),
            character: characterBucket(from: tone, hasTranscript: hasTranscript),
            inferredOnly: inferredOnly
        )
    }

    private static func paceBucket(from tone: String, hasTranscript: Bool) -> PaceBucket {
        if tone.contains("fast urgent") { return .fast }
        if tone.contains("slow deliberate") { return .slow }
        if tone.contains("normal conversational") { return .normal }
        if hasTranscript, !AudioToneLabels.isSilentDescription(tone) { return .normal }
        return .unknown
    }

    private static func energyBucket(from tone: String) -> EnergyBucket {
        if tone.contains("energetic loud") { return .energetic }
        if tone.contains("moderate-energy") { return .moderate }
        if tone.contains("calm") { return .calm }
        if tone.contains("quiet") { return .quiet }
        if AudioToneLabels.isSilentDescription(tone) { return .silent }
        return .unknown
    }

    private static func characterBucket(from tone: String, hasTranscript: Bool) -> CharacterBucket {
        if AudioToneLabels.isSilentDescription(tone), !hasTranscript { return .silent }
        if tone.contains("speech-over-music") { return .speechOverMusic }
        if tone.contains("music-heavy") || tone.contains("music") { return .music }
        if tone.contains("spoken") || hasTranscript { return .spoken }
        if tone.contains("ambient") { return .ambient }
        return .unknown
    }

    private static func majority<T: Hashable>(_ values: [T]) -> T? {
        guard !values.isEmpty else { return nil }
        var counts: [T: Int] = [:]
        for value in values {
            counts[value, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }
}
