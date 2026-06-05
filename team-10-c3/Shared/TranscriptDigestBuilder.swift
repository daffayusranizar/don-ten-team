//
//  TranscriptDigestBuilder.swift
//  team-10-c3
//

import Foundation

/// Builds bounded, sanitized session transcript digests for persistence and daily insight prompts.
enum TranscriptDigestBuilder {
    static let defaultMaxLength = 1200
    static let sessionCardExcerptLength = 280
    static let briefSummaryMaxLength = 300

    static func buildDigest(
        perWindowTranscripts: [String?],
        fullTrackText: String? = nil,
        maxLength: Int = defaultMaxLength
    ) -> String? {
        var segments: [String] = []

        for raw in perWindowTranscripts {
            guard let cleaned = TranscriptSanitizer.meaningfulForStorage(raw ?? "") else { continue }
            if segments.last != cleaned {
                segments.append(cleaned)
            }
        }

        if segments.isEmpty, let fullTrackText {
            if let cleaned = TranscriptSanitizer.meaningfulForStorage(fullTrackText) {
                segments.append(cleaned)
            }
        } else if segments.count < 2, let fullTrackText,
                  let cleaned = TranscriptSanitizer.meaningfulForStorage(fullTrackText) {
            if !segments.contains(cleaned) {
                segments.append(cleaned)
            }
        }

        guard !segments.isEmpty else { return nil }
        return cap(segments.joined(separator: " "), maxLength: maxLength)
    }

    static func buildDigest(from screens: [ScreenBreakdownItem], maxLength: Int = defaultMaxLength) -> String? {
        buildDigest(
            perWindowTranscripts: screens.map(\.audioTranscript),
            fullTrackText: nil,
            maxLength: maxLength
        )
    }

    static func buildDigest(from screens: [StoredScreenBreakdown], maxLength: Int = defaultMaxLength) -> String? {
        buildDigest(
            perWindowTranscripts: screens.map(\.audioTranscript),
            fullTrackText: nil,
            maxLength: maxLength
        )
    }

    static func buildDigest(
        timeline: [FrameClassificationSummary],
        fullTrackText: String? = nil,
        maxLength: Int = defaultMaxLength
    ) -> String? {
        buildDigest(
            perWindowTranscripts: timeline.map(\.audioTranscript),
            fullTrackText: fullTrackText,
            maxLength: maxLength
        )
    }

    /// First N characters for session-complete card when `sessionTranscriptExcerpt` is nil.
    static func cardExcerpt(from digest: String?, maxLength: Int = sessionCardExcerptLength) -> String? {
        guard let digest, TranscriptSanitizer.isMeaningful(digest) else { return nil }
        return cap(digest, maxLength: maxLength)
    }

    static func resolvedDigest(
        stored: String?,
        screens: [ScreenBreakdownItem]
    ) -> String? {
        if let stored, TranscriptSanitizer.isMeaningful(stored) {
            return stored
        }
        return buildDigest(from: screens)
    }

    /// Bounded thematic summary safe to pass into on-device LLM prompts.
    static func buildBriefSummary(
        fullTrackText: String?,
        digest: String?,
        maxLength: Int = briefSummaryMaxLength
    ) -> String? {
        let source: String?
        if let fullTrackText, TranscriptSanitizer.isMeaningful(fullTrackText) {
            source = fullTrackText
        } else if let digest, TranscriptSanitizer.isMeaningful(digest) {
            source = digest
        } else {
            source = nil
        }
        guard let source else { return nil }

        let cleaned = TranscriptSanitizer.sanitize(source)
        let sentences = cleaned
            .split(whereSeparator: { $0 == "." || $0 == "!" || $0 == "?" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { TranscriptSanitizer.isMeaningful($0) }

        var unique: [String] = []
        for sentence in sentences {
            let normalized = sentence.lowercased()
            if !unique.contains(where: { $0.lowercased() == normalized }) {
                unique.append(sentence)
            }
        }

        let joined = unique.joined(separator: ". ")
        guard TranscriptSanitizer.isMeaningful(joined) else { return nil }
        let withPunctuation = joined.hasSuffix(".") || joined.hasSuffix("!") || joined.hasSuffix("?")
            ? joined
            : joined + "."
        return cap(withPunctuation, maxLength: maxLength)
    }

    private static func cap(_ text: String, maxLength: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLength else { return trimmed }
        let end = trimmed.index(trimmed.startIndex, offsetBy: maxLength)
        return String(trimmed[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}
