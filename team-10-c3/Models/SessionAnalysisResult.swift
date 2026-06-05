import Foundation

/// Legacy tone types kept for decoding stored session payloads.
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

/// This is the final object your ParentingEngine will return to the UI team.
public struct SessionAnalysisResult: Sendable {
    /// The overarching category (e.g., .educational, .entertainment, .commercial)
    public let dominantCategory: ClassificationCategory
    
    /// The final, parent-friendly AI written paragraph.
    public let aiProseSummary: String
    
    /// Suggested actions and advice for the parent based on the session.
    public let guidance: GuidanceSuggestion
    
    /// The full chronological breakdown of what happened every 3 seconds.
    public let timeline: [FrameClassificationSummary]

    /// Educational / Entertainment / Commercial percentages for the Insight chart.
    public let categoryBreakdown: UsageCategoryBreakdown

    /// Full-session speech excerpt when per-window transcripts are mostly empty but Whisper succeeded on the full track.
    public let sessionTranscriptExcerpt: String?

    /// Bounded digest of per-window and full-track speech for daily insight and session review.
    public let sessionTranscriptDigest: String?

    /// Short sanitized transcript summary safe for LLM prompts.
    public let sessionTranscriptBriefSummary: String?

    /// Deprecated — kept for stored JSON compatibility.
    public let topCreatorsSeen: [String]

    /// Deprecated — kept for stored JSON compatibility.
    public let concernSignals: [ConcernSignal]

    /// Deprecated — kept for stored JSON compatibility.
    public let sessionToneSummary: SessionToneSummary?

    public init(
        dominantCategory: ClassificationCategory,
        aiProseSummary: String,
        guidance: GuidanceSuggestion,
        timeline: [FrameClassificationSummary],
        categoryBreakdown: UsageCategoryBreakdown,
        sessionTranscriptExcerpt: String? = nil,
        sessionTranscriptDigest: String? = nil,
        sessionTranscriptBriefSummary: String? = nil,
        topCreatorsSeen: [String] = [],
        concernSignals: [ConcernSignal] = [],
        sessionToneSummary: SessionToneSummary? = nil
    ) {
        self.dominantCategory = dominantCategory
        self.aiProseSummary = aiProseSummary
        self.guidance = guidance
        self.timeline = timeline
        self.categoryBreakdown = categoryBreakdown
        self.sessionTranscriptExcerpt = sessionTranscriptExcerpt
        self.sessionTranscriptDigest = sessionTranscriptDigest
        self.sessionTranscriptBriefSummary = sessionTranscriptBriefSummary
        self.topCreatorsSeen = topCreatorsSeen
        self.concernSignals = concernSignals
        self.sessionToneSummary = sessionToneSummary
    }
}

/// Deprecated — kept for stored JSON compatibility.
public struct ConcernSignal: Sendable {
    public let id = UUID()
    public let title: String
    public let description: String
    public let severity: SeverityLevel
    
    public enum SeverityLevel: Sendable {
        case low, medium, high
    }
    
    public init(title: String, description: String, severity: SeverityLevel) {
        self.title = title
        self.description = description
        self.severity = severity
    }
}

/// Actionable advice given to the parent.
public struct GuidanceSuggestion: Sendable {
    /// Questions a parent can ask the child (e.g., "What was your favorite part of that Minecraft video?")
    public let conversationStarters: [String]
    
    /// A suggested real-world activity to transition them off the screen.
    public let offlineActivity: String
    
    public init(conversationStarters: [String], offlineActivity: String) {
        self.conversationStarters = conversationStarters
        self.offlineActivity = offlineActivity
    }
}
