import Foundation

/// This is the final object your ParentingEngine will return to the UI team.
public struct SessionAnalysisResult: Sendable {
    /// The overarching category (e.g., .educational, .entertainment, .commercial)
    public let dominantCategory: ClassificationCategory
    
    /// The final, parent-friendly AI written paragraph.
    public let aiProseSummary: String
    
    /// The top creator handles found on the screen (e.g., "@MrBeast", "@MsRachel")
    public let topCreatorsSeen: [String]
    
    /// Detailed flags triggered by this session (e.g., heavy commercial exposure)
    public let concernSignals: [ConcernSignal]
    
    /// Suggested actions and advice for the parent based on the session.
    public let guidance: GuidanceSuggestion
    
    /// The full chronological breakdown of what happened every 3 seconds.
    public let timeline: [FrameClassificationSummary]

    /// Full-session speech excerpt when per-window transcripts are mostly empty but Whisper succeeded on the full track.
    public let sessionTranscriptExcerpt: String?

    public init(
        dominantCategory: ClassificationCategory,
        aiProseSummary: String,
        topCreatorsSeen: [String],
        concernSignals: [ConcernSignal],
        guidance: GuidanceSuggestion,
        timeline: [FrameClassificationSummary],
        sessionTranscriptExcerpt: String? = nil
    ) {
        self.dominantCategory = dominantCategory
        self.aiProseSummary = aiProseSummary
        self.topCreatorsSeen = topCreatorsSeen
        self.concernSignals = concernSignals
        self.guidance = guidance
        self.timeline = timeline
        self.sessionTranscriptExcerpt = sessionTranscriptExcerpt
    }
}

/// Represents a specific issue detected during the session that the parent should know about.
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