import Foundation

/// Analyzes the final timeline and generates actionable parenting advice
public actor GuidanceEngine {
    
    public init() {}
    
    public func generateInsights(
        timeline: [FrameClassificationSummary], 
        dominantCategory: String,
        child: Child? = nil
    ) -> (guidance: GuidanceSuggestion, signals: [ConcernSignal]) {
        
        let signals = detectPatterns(in: timeline)
        let guidance = fetchPlaybook(for: dominantCategory, signals: signals, child: child)
        
        return (guidance, signals)
    }
    
    // MARK: - Pattern Detection
    
    private func detectPatterns(in timeline: [FrameClassificationSummary]) -> [ConcernSignal] {
        var signals: [ConcernSignal] = []
        let totalFrames = max(1, timeline.count)
        
        // 1. Calculate Commercial Exposure
        let commercialCount = timeline.filter { $0.label.contains("Commercial") }.count
        let commercialPercentage = Float(commercialCount) / Float(totalFrames)
        
        if commercialPercentage > 0.3 {
            signals.append(ConcernSignal(
                title: "High Commercial Exposure",
                description: "Over 30% of this session consisted of sponsored content, unboxing, or advertisements.",
                severity: .high
            ))
        } else if commercialPercentage > 0.1 {
            signals.append(ConcernSignal(
                title: "Moderate Commercial Exposure",
                description: "Some sponsored content or advertisements were detected.",
                severity: .medium
            ))
        }
        
        // 2. Calculate Fast-Paced Audio
        let fastPacedCount = timeline.filter { $0.audioTone?.contains("fast") == true }.count
        let fastPacedPercentage = Float(fastPacedCount) / Float(totalFrames)
        
        if fastPacedPercentage > 0.5 {
            signals.append(ConcernSignal(
                title: "High-Stimulation Audio",
                description: "The majority of this session featured fast, urgent speech which can be overstimulating.",
                severity: .medium
            ))
        }
        
        return signals
    }
    
    // MARK: - Guidance Playbook
    
    private func fetchPlaybook(for category: String, signals: [ConcernSignal], child: Child?) -> GuidanceSuggestion {
        let name = child?.name ?? "your child"
        let age = child?.currentAge ?? 8
        
        // If there is high commercial exposure, override the standard category advice
        if signals.contains(where: { $0.title.contains("Commercial") }) {
            return GuidanceSuggestion(
                conversationStarters: [
                    "Did you see any cool toys in that video, \(name)?",
                    "Did you know those creators get paid to play with those toys?",
                    "Do you think real life is as exciting as those videos make it look?"
                ],
                offlineActivity: age < 8 ? "Let's play 'Store' in the living room and practice counting coins!" : "Let's talk about how advertisements work and try to spot ads in a magazine."
            )
        }
        
        // Otherwise, fall back to the dominant category
        if category.contains("Entertainment") {
            return GuidanceSuggestion(
                conversationStarters: [
                    "What was the funniest part of the video you watched, \(name)?",
                    "Who was your favorite person in that video and why?",
                    "If you made a YouTube video, what would it be about?"
                ],
                offlineActivity: age < 8 ? "Let's build a fort out of blankets!" : "Let's go for a 20-minute walk or bike ride to give your eyes a break."
            )
        } else if category.contains("Educational") {
            return GuidanceSuggestion(
                conversationStarters: [
                    "What was the coolest fact you learned today, \(name)?",
                    "Can you teach me how to do what they just showed in the video?",
                    "Did anything in that video surprise you?"
                ],
                offlineActivity: age < 8 ? "Why don't we draw something related to what you just learned?" : "Let's look up more information about that topic in a book or online together."
            )
        } else {
            // Fallback for Mixed/Unknown content
            return GuidanceSuggestion(
                conversationStarters: [
                    "What were you watching, \(name)?",
                    "Did you see anything interesting?"
                ],
                offlineActivity: "Let's take a 15-minute screen break."
            )
        }
    }
}