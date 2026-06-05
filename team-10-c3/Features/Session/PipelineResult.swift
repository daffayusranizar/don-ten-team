//
//  PipelineResult.swift
//  team-10-c3
//

import Foundation
import UIKit

/// UI model for session-level AI analysis plus per-screen timeline (persisted via SessionAnalysisStore).
struct PipelineResult {
    let category: String
    let summary: String
    let creators: [String]
    let signals: [String]
    let conversationStarters: [String]
    let offlineActivity: String
    let categoryBreakdown: UsageCategoryBreakdown
    let sessionTranscriptExcerpt: String?
    let sessionTranscriptDigest: String?
    let sessionToneSummary: SessionToneSummary?
    let screens: [ScreenBreakdownItem]

    /// Transcript text for session-complete card (excerpt or digest prefix).
    var sessionTranscriptForDisplay: String? {
        if let excerpt = sessionTranscriptExcerpt,
           TranscriptSanitizer.isMeaningful(excerpt) {
            return excerpt
        }
        return TranscriptDigestBuilder.cardExcerpt(from: sessionTranscriptDigest)
            ?? TranscriptDigestBuilder.cardExcerpt(
                from: TranscriptDigestBuilder.buildDigest(from: screens)
            )
    }

    /// First starter for older call sites.
    var conversationStarter: String {
        conversationStarters.first ?? "—"
    }

    /// Kept for older call sites; prefer `screens`.
    var timelineItems: [ScreenBreakdownItem] { screens }

    init(from result: SessionAnalysisResult) {
        self.category = result.dominantCategory.name
        self.summary = result.aiProseSummary
        self.creators = result.topCreatorsSeen
        self.signals = result.concernSignals.map { "[\($0.severity)] \($0.title): \($0.description)" }
        let starters = result.guidance.conversationStarters
        self.conversationStarters = Array(starters.prefix(3))
        self.offlineActivity = result.guidance.offlineActivity
        self.categoryBreakdown = result.categoryBreakdown
        self.sessionTranscriptExcerpt = result.sessionTranscriptExcerpt
        self.sessionTranscriptDigest = result.sessionTranscriptDigest
        self.sessionToneSummary = result.sessionToneSummary
        self.screens = result.timeline.map { ScreenBreakdownItem(frame: $0) }
    }

    init(stored: StoredPipelineResult) {
        category = stored.category
        summary = stored.summary
        creators = stored.creators
        signals = stored.signals
        conversationStarters = stored.resolvedConversationStarters
        offlineActivity = stored.offlineActivity
        categoryBreakdown = stored.resolvedCategoryBreakdown
        sessionTranscriptExcerpt = stored.sessionTranscriptExcerpt
        sessionTranscriptDigest = stored.sessionTranscriptDigest
            ?? TranscriptDigestBuilder.buildDigest(from: stored.screens)
        sessionToneSummary = stored.sessionToneSummary
            ?? SessionToneSummarizer.summarize(screens: stored.screens)
        screens = stored.screens.map(ScreenBreakdownItem.init(stored:))
    }
}

/// One analyzed screen segment (~3s bucket from the recording pipeline).
struct ScreenBreakdownItem: Identifiable, Hashable {
    let id: Int
    let timestampLabel: String
    let timestampSeconds: TimeInterval
    let categoryLabel: String
    let contentSummary: String?
    let creatorHandle: String?
    let confidence: Float?
    let thumbnail: UIImage?
    let bottomCropThumbnail: UIImage?
    let audioTranscript: String?
    let audioTone: String?
    let audioLabel: String?

    init(frame: FrameClassificationSummary) {
        id = frame.id
        timestampSeconds = frame.timestamp
        timestampLabel = Self.formatTimestamp(frame.timestamp)
        categoryLabel = frame.label
        contentSummary = frame.contentSummary
        creatorHandle = frame.creatorHandle
        confidence = frame.probability
        thumbnail = frame.thumbnail
        bottomCropThumbnail = frame.bottomCropThumbnail
        audioTranscript = frame.audioTranscript
        audioTone = frame.audioTone
        audioLabel = frame.audioLabel
    }

    init(stored: StoredScreenBreakdown) {
        id = stored.id
        timestampLabel = stored.timestampLabel
        timestampSeconds = stored.timestampSeconds
        categoryLabel = stored.categoryLabel
        contentSummary = stored.contentSummary
        creatorHandle = stored.creatorHandle
        confidence = stored.confidence
        thumbnail = nil
        bottomCropThumbnail = nil
        audioTranscript = stored.audioTranscript
        audioTone = stored.audioTone
        audioLabel = stored.audioLabel
    }

    init(
        id: Int,
        timestampLabel: String,
        timestampSeconds: TimeInterval,
        categoryLabel: String,
        contentSummary: String?,
        creatorHandle: String?,
        confidence: Float?,
        thumbnail: UIImage?,
        bottomCropThumbnail: UIImage?,
        audioTranscript: String?,
        audioTone: String?,
        audioLabel: String?
    ) {
        self.id = id
        self.timestampLabel = timestampLabel
        self.timestampSeconds = timestampSeconds
        self.categoryLabel = categoryLabel
        self.contentSummary = contentSummary
        self.creatorHandle = creatorHandle
        self.confidence = confidence
        self.thumbnail = thumbnail
        self.bottomCropThumbnail = bottomCropThumbnail
        self.audioTranscript = audioTranscript
        self.audioTone = audioTone
        self.audioLabel = audioLabel
    }

    var confidencePercentText: String? {
        guard let confidence else { return nil }
        return "\(Int((confidence * 100).rounded()))% confidence"
    }

    var meaningfulAudioTranscript: String? {
        TranscriptSanitizer.meaningfulForStorage(audioTranscript ?? "")
    }

    var isSilentOrUnreadableTone: Bool {
        AudioToneLabels.isSilentDescription(audioTone ?? "")
    }

    var hasAudioDetails: Bool {
        if meaningfulAudioTranscript != nil { return true }
        if let label = audioLabel?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty {
            return true
        }
        let tone = audioTone?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !tone.isEmpty else { return false }
        return !isSilentOrUnreadableTone
    }

    var hasScreenshots: Bool {
        thumbnail != nil || bottomCropThumbnail != nil
    }

    static func formatTimestamp(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ScreenBreakdownItem, rhs: ScreenBreakdownItem) -> Bool {
        lhs.id == rhs.id
    }
}

#if DEBUG
extension PipelineResult {
    init(
        category: String,
        summary: String,
        creators: [String],
        signals: [String],
        conversationStarter: String,
        offlineActivity: String,
        categoryBreakdown: UsageCategoryBreakdown = .empty,
        screens: [ScreenBreakdownItem],
        sessionTranscriptExcerpt: String? = nil,
        sessionTranscriptDigest: String? = nil,
        sessionToneSummary: SessionToneSummary? = nil
    ) {
        self.category = category
        self.summary = summary
        self.creators = creators
        self.signals = signals
        self.conversationStarters = [conversationStarter]
        self.offlineActivity = offlineActivity
        self.categoryBreakdown = categoryBreakdown
        self.sessionTranscriptExcerpt = sessionTranscriptExcerpt
        self.sessionTranscriptDigest = sessionTranscriptDigest
        self.sessionToneSummary = sessionToneSummary
        self.screens = screens
    }
}

extension ScreenBreakdownItem {
    static var preview: ScreenBreakdownItem {
        ScreenBreakdownItem(
            id: 0,
            timestampLabel: "1:03",
            timestampSeconds: 63,
            categoryLabel: "Educational",
            contentSummary: "Creator explains a science concept with on-screen captions.",
            creatorHandle: "@ExampleCreator",
            confidence: 0.82,
            thumbnail: nil,
            bottomCropThumbnail: nil,
            audioTranscript: "Today we're learning about plants.",
            audioTone: "Calm",
            audioLabel: "Educational speech"
        )
    }

}
#endif
