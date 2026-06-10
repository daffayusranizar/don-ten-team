//
//  SessionAnalysisRecord.swift
//  team-10-c3
//

import Foundation
import SwiftData

/// Persisted AI analysis for one session (keyed by start-marker `sessionId`).
@Model
final class SessionAnalysisRecord {
    var sessionId: UUID
    var childId: UUID
    var statusRaw: String
    var errorMessage: String?
    var payloadJSON: String?
    var summaryPreview: String?
    var dominantCategory: String?
    var screenCount: Int
    var analyzedAt: Date

    init(
        sessionId: UUID,
        childId: UUID,
        status: SessionAnalysisStatus,
        errorMessage: String? = nil,
        payloadJSON: String? = nil,
        summaryPreview: String? = nil,
        dominantCategory: String? = nil,
        screenCount: Int = 0,
        analyzedAt: Date = Date()
    ) {
        self.sessionId = sessionId
        self.childId = childId
        self.statusRaw = status.rawValue
        self.errorMessage = errorMessage
        self.payloadJSON = payloadJSON
        self.summaryPreview = summaryPreview
        self.dominantCategory = dominantCategory
        self.screenCount = screenCount
        self.analyzedAt = analyzedAt
    }

    var status: SessionAnalysisStatus {
        get { SessionAnalysisStatus(rawValue: statusRaw) ?? .failed }
        set { statusRaw = newValue.rawValue }
    }
}

enum SessionAnalysisStatus: String, Codable {
    case completed
    case failed
}

@Model
final class WeeklyInsightCacheRecord {
    var childId: UUID
    var weekKey: String
    var sessionSignature: String
    var aiSummary: String
    var aiSummaryDetail: String
    var weeklySuggestion: String
    var followUpOptionsJSON: String
    var builtAt: Date

    init(
        childId: UUID,
        weekKey: String,
        sessionSignature: String,
        aiSummary: String,
        aiSummaryDetail: String = "",
        weeklySuggestion: String,
        followUpOptionsJSON: String,
        builtAt: Date = Date()
    ) {
        self.childId = childId
        self.weekKey = weekKey
        self.sessionSignature = sessionSignature
        self.aiSummary = aiSummary
        self.aiSummaryDetail = aiSummaryDetail
        self.weeklySuggestion = weeklySuggestion
        self.followUpOptionsJSON = followUpOptionsJSON
        self.builtAt = builtAt
    }
}

@Model
final class WeeklySuggestionTryRecord {
    var id: UUID
    var childId: UUID
    var weekKey: String
    var suggestion: String
    var tried: Bool
    var followUpOptionsJSON: String
    var followUpSelection: String?
    var note: String?
    var savedAt: Date

    init(
        id: UUID = UUID(),
        childId: UUID,
        weekKey: String,
        suggestion: String,
        tried: Bool,
        followUpOptionsJSON: String,
        followUpSelection: String? = nil,
        note: String? = nil,
        savedAt: Date = Date()
    ) {
        self.id = id
        self.childId = childId
        self.weekKey = weekKey
        self.suggestion = suggestion
        self.tried = tried
        self.followUpOptionsJSON = followUpOptionsJSON
        self.followUpSelection = followUpSelection
        self.note = note
        self.savedAt = savedAt
    }
}

@Model
final class DailyInsightCacheRecord {
    var childId: UUID
    var dayKey: String
    var sessionSignature: String
    var summary: String
    var detailSummary: String
    var builtAt: Date

    init(
        childId: UUID,
        dayKey: String,
        sessionSignature: String,
        summary: String,
        detailSummary: String = "",
        builtAt: Date = Date()
    ) {
        self.childId = childId
        self.dayKey = dayKey
        self.sessionSignature = sessionSignature
        self.summary = summary
        self.detailSummary = detailSummary
        self.builtAt = builtAt
    }
}

/// JSON-safe pipeline snapshot (no thumbnails).
struct StoredPipelineResult: Codable {
    let category: String
    let summary: String
    let creators: [String]
    let signals: [String]
    let offlineActivity: String
    let categoryBreakdown: UsageCategoryBreakdown?
    let sessionTranscriptExcerpt: String?
    let sessionTranscriptDigest: String?
    let sessionTranscriptBriefSummary: String?
    let screens: [StoredScreenBreakdown]

    var resolvedCategoryBreakdown: UsageCategoryBreakdown {
        let fromScreens = UsageCategoryBreakdown.from(screens: screens)
        if !fromScreens.isEmpty { return fromScreens }
        return categoryBreakdown ?? .empty
    }

    enum CodingKeys: String, CodingKey {
        case category, summary, creators, signals
        case conversationStarter, conversationStarters
        case offlineActivity, categoryBreakdown, sessionTranscriptExcerpt
        case sessionTranscriptDigest, sessionTranscriptBriefSummary, screens
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        category = try container.decode(String.self, forKey: .category)
        summary = try container.decode(String.self, forKey: .summary)
        creators = try container.decode([String].self, forKey: .creators)
        signals = try container.decode([String].self, forKey: .signals)
        _ = try container.decodeIfPresent(String.self, forKey: .conversationStarter)
        _ = try container.decodeIfPresent([String].self, forKey: .conversationStarters)
        offlineActivity = try container.decode(String.self, forKey: .offlineActivity)
        categoryBreakdown = try container.decodeIfPresent(UsageCategoryBreakdown.self, forKey: .categoryBreakdown)
        sessionTranscriptExcerpt = try container.decodeIfPresent(String.self, forKey: .sessionTranscriptExcerpt)
        sessionTranscriptDigest = try container.decodeIfPresent(String.self, forKey: .sessionTranscriptDigest)
        sessionTranscriptBriefSummary = try container.decodeIfPresent(String.self, forKey: .sessionTranscriptBriefSummary)
        screens = try container.decode([StoredScreenBreakdown].self, forKey: .screens)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(category, forKey: .category)
        try container.encode(summary, forKey: .summary)
        try container.encode(creators, forKey: .creators)
        try container.encode(signals, forKey: .signals)
        try container.encode(offlineActivity, forKey: .offlineActivity)
        try container.encodeIfPresent(categoryBreakdown, forKey: .categoryBreakdown)
        try container.encodeIfPresent(sessionTranscriptExcerpt, forKey: .sessionTranscriptExcerpt)
        try container.encodeIfPresent(sessionTranscriptDigest, forKey: .sessionTranscriptDigest)
        try container.encodeIfPresent(sessionTranscriptBriefSummary, forKey: .sessionTranscriptBriefSummary)
        try container.encode(screens, forKey: .screens)
    }
}

struct StoredScreenBreakdown: Codable {
    let id: Int
    let timestampLabel: String
    let timestampSeconds: Double
    let categoryLabel: String
    let contentSummary: String?
    let videoMatchedPrompt: String?
    let matchedPrompt: String?
    let onScreenTranscript: String?
    let onScreenBriefSummary: String?
    let creatorHandle: String?
    let confidence: Float?
    let audioTranscript: String?
    let audioTone: String?
    let audioLabel: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        timestampLabel = try container.decode(String.self, forKey: .timestampLabel)
        timestampSeconds = try container.decode(Double.self, forKey: .timestampSeconds)
        categoryLabel = try container.decode(String.self, forKey: .categoryLabel)
        contentSummary = try container.decodeIfPresent(String.self, forKey: .contentSummary)
        videoMatchedPrompt = try container.decodeIfPresent(String.self, forKey: .videoMatchedPrompt)
        matchedPrompt = try container.decodeIfPresent(String.self, forKey: .matchedPrompt)
        onScreenTranscript = try container.decodeIfPresent(String.self, forKey: .onScreenTranscript)
        onScreenBriefSummary = try container.decodeIfPresent(String.self, forKey: .onScreenBriefSummary)
        creatorHandle = try container.decodeIfPresent(String.self, forKey: .creatorHandle)
        confidence = try container.decodeIfPresent(Float.self, forKey: .confidence)
        audioTranscript = try container.decodeIfPresent(String.self, forKey: .audioTranscript)
        audioTone = try container.decodeIfPresent(String.self, forKey: .audioTone)
        audioLabel = try container.decodeIfPresent(String.self, forKey: .audioLabel)
    }

    enum CodingKeys: String, CodingKey {
        case id, timestampLabel, timestampSeconds, categoryLabel, contentSummary
        case videoMatchedPrompt, matchedPrompt, onScreenTranscript, onScreenBriefSummary
        case creatorHandle, confidence
        case audioTranscript, audioTone, audioLabel
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestampLabel, forKey: .timestampLabel)
        try container.encode(timestampSeconds, forKey: .timestampSeconds)
        try container.encode(categoryLabel, forKey: .categoryLabel)
        try container.encodeIfPresent(contentSummary, forKey: .contentSummary)
        try container.encodeIfPresent(videoMatchedPrompt, forKey: .videoMatchedPrompt)
        try container.encodeIfPresent(matchedPrompt, forKey: .matchedPrompt)
        try container.encodeIfPresent(onScreenTranscript, forKey: .onScreenTranscript)
        try container.encodeIfPresent(onScreenBriefSummary, forKey: .onScreenBriefSummary)
        try container.encodeIfPresent(creatorHandle, forKey: .creatorHandle)
        try container.encodeIfPresent(confidence, forKey: .confidence)
        try container.encodeIfPresent(audioTranscript, forKey: .audioTranscript)
        try container.encodeIfPresent(audioTone, forKey: .audioTone)
        try container.encodeIfPresent(audioLabel, forKey: .audioLabel)
    }
}

extension StoredPipelineResult {
    init(from result: PipelineResult) {
        category = result.category
        summary = result.summary
        creators = result.creators
        signals = result.signals
        offlineActivity = result.offlineActivity
        categoryBreakdown = result.categoryBreakdown
        sessionTranscriptExcerpt = result.sessionTranscriptExcerpt
        sessionTranscriptDigest = result.sessionTranscriptDigest
        sessionTranscriptBriefSummary = result.sessionTranscriptBriefSummary
        screens = result.screens.map(StoredScreenBreakdown.init)
    }
}

extension StoredScreenBreakdown {
    init(from item: ScreenBreakdownItem) {
        id = item.id
        timestampLabel = item.timestampLabel
        timestampSeconds = item.timestampSeconds
        categoryLabel = item.categoryLabel
        contentSummary = item.contentSummary
        videoMatchedPrompt = item.videoMatchedPrompt
        matchedPrompt = item.matchedPrompt
        onScreenTranscript = item.onScreenTranscript
        onScreenBriefSummary = item.onScreenBriefSummary
        creatorHandle = item.creatorHandle
        confidence = item.confidence
        audioTranscript = item.audioTranscript
        audioTone = item.audioTone
        audioLabel = item.audioLabel
    }
}
