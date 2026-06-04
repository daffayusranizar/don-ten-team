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
        let guidance = fetchPlaybook(
            for: dominantCategory,
            signals: signals,
            timeline: timeline,
            child: child
        )

        return (guidance, signals)
    }

    // MARK: - Pattern Detection

    private func detectPatterns(in timeline: [FrameClassificationSummary]) -> [ConcernSignal] {
        var signals: [ConcernSignal] = []
        let totalFrames = max(1, timeline.count)

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

        let fastPacedCount = timeline.filter { $0.audioTone?.lowercased().contains("fast") == true }.count
        let fastPacedPercentage = Float(fastPacedCount) / Float(totalFrames)

        if fastPacedPercentage > 0.5 {
            signals.append(ConcernSignal(
                title: "High-Stimulation Audio",
                description: "Much of this session had fast, urgent speech, which can feel overstimulating.",
                severity: .medium
            ))
        }

        let educationalCount = timeline.filter { $0.label.contains("Educational") }.count
        let educationalPercentage = Float(educationalCount) / Float(totalFrames)
        let hasHighNegativeAudio = signals.contains { $0.title == "Negative Audio Detected" }

        if educationalPercentage > 0.4,
           commercialPercentage < 0.1,
           !hasHighNegativeAudio {
            signals.append(ConcernSignal(
                title: "Learning-Focused Session",
                description: "A good share of this session looked educational. A curious follow-up question could reinforce what they learned.",
                severity: .low
            ))
        }

        return signals
    }

    // MARK: - Guidance Playbook

    private func fetchPlaybook(
        for category: String,
        signals: [ConcernSignal],
        timeline: [FrameClassificationSummary],
        child: Child?
    ) -> GuidanceSuggestion {
        let name = child?.name ?? "your child"
        let age = child?.currentAge ?? 8
        let topicHint = topicHint(from: timeline)

        let base: GuidanceSuggestion
        if signals.contains(where: { $0.title.contains("Commercial") }) {
            base = GuidanceSuggestion(
                conversationStarters: [
                    "What stood out to you in that video, \(name)?",
                    "Some creators get paid to show products—did you notice anything like that?",
                    "How does real life compare to what you saw on screen?"
                ],
                offlineActivity: age < 8
                    ? "Let's play 'Store' in the living room and practice counting coins!"
                    : "Let's talk about how ads work and try spotting one in a magazine together."
            )
        } else if signals.contains(where: { $0.title.contains("Stimulation") }) {
            base = GuidanceSuggestion(
                conversationStarters: [
                    "That sounded pretty energetic—how did it feel to watch, \(name)?",
                    "When do you feel most calm after screen time?",
                    "What would a slower-paced video look like for you?"
                ],
                offlineActivity: age < 8
                    ? "Let's do a quiet drawing or puzzle for 15 minutes."
                    : "Let's take a short walk and talk about something unrelated to screens."
            )
        } else if category.contains("Educational") {
            let topicLine = educationalStarter(topicHint: topicHint, name: name)
            base = GuidanceSuggestion(
                conversationStarters: [
                    topicLine,
                    "Can you teach me one thing from what you watched?",
                    "What surprised you or made you want to learn more?"
                ],
                offlineActivity: age < 8
                    ? "Let's draw or build something related to what you learned."
                    : "Let's look up one more fact about that topic together—in a book or safely online."
            )
        } else if category.contains("Entertainment") {
            base = GuidanceSuggestion(
                conversationStarters: [
                    "What was the funniest or most interesting part, \(name)?",
                    "Who did you enjoy watching most and why?",
                    "If you made your own video, what would it be about?"
                ],
                offlineActivity: age < 8
                    ? "Let's build a fort out of blankets!"
                    : "Let's go for a 20-minute walk or bike ride to give your eyes a break."
            )
        } else {
            base = GuidanceSuggestion(
                conversationStarters: [
                    "What were you watching, \(name)?",
                    "What did you like or not like about it?",
                    "Would you watch something like that again?"
                ],
                offlineActivity: "Let's take a 15-minute screen break together."
            )
        }

        let ordered = orderedStarters(base.conversationStarters, signals: signals)
        return GuidanceSuggestion(
            conversationStarters: ordered,
            offlineActivity: base.offlineActivity
        )
    }

    private func orderedStarters(_ starters: [String], signals: [ConcernSignal]) -> [String] {
        guard starters.count >= 2 else { return starters }
        var ordered = starters
        if signals.contains(where: { $0.title.contains("Commercial") }) {
            ordered = [starters[1], starters[0]] + starters.dropFirst(2)
        } else if signals.contains(where: { $0.title.contains("Stimulation") }) {
            ordered = [starters[0], starters[2], starters[1]]
        }
        return Array(ordered.prefix(3))
    }

    private func educationalStarter(topicHint: String?, name: String) -> String {
        if let hint = topicHint, !hint.isEmpty {
            return "You watched something about \(hint)—what did you take away from it, \(name)?"
        }
        return "What was the coolest thing you learned today, \(name)?"
    }

    private func topicHint(from timeline: [FrameClassificationSummary]) -> String? {
        let combined = timeline
            .compactMap(\.contentSummary)
            .joined(separator: " ")
            .lowercased()
        let keywords = ["swift", "programming", "science", "math", "history", "coding", "tutorial"]
        for word in keywords where combined.contains(word) {
            return word.capitalized
        }
        if combined.contains("educational") {
            return "learning"
        }
        return nil
    }
}
