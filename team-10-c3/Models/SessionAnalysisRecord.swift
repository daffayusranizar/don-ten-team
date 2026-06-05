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
    var analyzedAt: Date

    init(
        sessionId: UUID,
        childId: UUID,
        status: SessionAnalysisStatus,
        errorMessage: String? = nil,
        payloadJSON: String? = nil,
        analyzedAt: Date = Date()
    ) {
        self.sessionId = sessionId
        self.childId = childId
        self.statusRaw = status.rawValue
        self.errorMessage = errorMessage
        self.payloadJSON = payloadJSON
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

/// JSON-safe pipeline snapshot (no thumbnails).
struct StoredPipelineResult: Codable {
    let category: String
    let summary: String
    let creators: [String]
    let signals: [String]
    let conversationStarter: String?
    let conversationStarters: [String]?
    let offlineActivity: String
    let categoryBreakdown: UsageCategoryBreakdown?
    let sessionTranscriptExcerpt: String?
    let sessionTranscriptDigest: String?
    let sessionToneSummary: SessionToneSummary?
    let screens: [StoredScreenBreakdown]

    var resolvedCategoryBreakdown: UsageCategoryBreakdown {
        let fromScreens = UsageCategoryBreakdown.from(screens: screens)
        if !fromScreens.isEmpty { return fromScreens }
        return categoryBreakdown ?? .empty
    }

    var resolvedConversationStarters: [String] {
        if let conversationStarters, !conversationStarters.isEmpty {
            return Array(conversationStarters.prefix(3))
        }
        if let conversationStarter, !conversationStarter.isEmpty {
            return [conversationStarter]
        }
        return ["—"]
    }

    enum CodingKeys: String, CodingKey {
        case category, summary, creators, signals
        case conversationStarter, conversationStarters
        case offlineActivity, categoryBreakdown, sessionTranscriptExcerpt
        case sessionTranscriptDigest, sessionToneSummary, screens
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        category = try container.decode(String.self, forKey: .category)
        summary = try container.decode(String.self, forKey: .summary)
        creators = try container.decode([String].self, forKey: .creators)
        signals = try container.decode([String].self, forKey: .signals)
        conversationStarter = try container.decodeIfPresent(String.self, forKey: .conversationStarter)
        conversationStarters = try container.decodeIfPresent([String].self, forKey: .conversationStarters)
        offlineActivity = try container.decode(String.self, forKey: .offlineActivity)
        categoryBreakdown = try container.decodeIfPresent(UsageCategoryBreakdown.self, forKey: .categoryBreakdown)
        sessionTranscriptExcerpt = try container.decodeIfPresent(String.self, forKey: .sessionTranscriptExcerpt)
        sessionTranscriptDigest = try container.decodeIfPresent(String.self, forKey: .sessionTranscriptDigest)
        sessionToneSummary = try container.decodeIfPresent(SessionToneSummary.self, forKey: .sessionToneSummary)
        screens = try container.decode([StoredScreenBreakdown].self, forKey: .screens)
    }
}

struct StoredScreenBreakdown: Codable {
    let id: Int
    let timestampLabel: String
    let timestampSeconds: Double
    let categoryLabel: String
    let contentSummary: String?
    let creatorHandle: String?
    let confidence: Float?
    let audioTranscript: String?
    let audioTone: String?
    let audioLabel: String?
}

extension StoredPipelineResult {
    init(from result: PipelineResult) {
        category = result.category
        summary = result.summary
        creators = result.creators
        signals = result.signals
        conversationStarter = result.conversationStarter
        conversationStarters = result.conversationStarters
        offlineActivity = result.offlineActivity
        categoryBreakdown = result.categoryBreakdown
        sessionTranscriptExcerpt = result.sessionTranscriptExcerpt
        sessionTranscriptDigest = result.sessionTranscriptDigest
        sessionToneSummary = result.sessionToneSummary
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
        creatorHandle = item.creatorHandle
        confidence = item.confidence
        audioTranscript = item.audioTranscript
        audioTone = item.audioTone
        audioLabel = item.audioLabel
    }
}
