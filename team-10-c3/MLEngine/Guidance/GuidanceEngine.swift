import Foundation

/// Analyzes the final timeline and generates actionable parenting advice
public actor GuidanceEngine {

    public init() {}

    public func generateGuidance(
        timeline: [FrameClassificationSummary],
        dominantCategory: String,
        child: Child? = nil
    ) -> GuidanceSuggestion {
        fetchPlaybook(
            for: dominantCategory,
            timeline: timeline,
            child: child
        )
    }

    private func fetchPlaybook(
        for category: String,
        timeline: [FrameClassificationSummary],
        child: Child?
    ) -> GuidanceSuggestion {
        let name = child?.name ?? "your child"
        let age = child?.currentAge ?? 8
        let topicHint = topicHint(from: timeline)

        if category.contains("Educational") {
            let topicLine = educationalStarter(topicHint: topicHint, name: name)
            return GuidanceSuggestion(
                conversationStarters: [
                    topicLine,
                    "Can you teach me one thing from what you watched?",
                    "What surprised you or made you want to learn more?"
                ],
                offlineActivity: age < 8
                    ? "Let's draw or build something related to what you learned."
                    : "Let's look up one more fact about that topic together—in a book or safely online."
            )
        }

        if category.contains("Entertainment") {
            return GuidanceSuggestion(
                conversationStarters: [
                    "What was the funniest or most interesting part, \(name)?",
                    "What did you enjoy watching most and why?",
                    "If you made your own video, what would it be about?"
                ],
                offlineActivity: age < 8
                    ? "Let's build a fort out of blankets!"
                    : "Let's go for a 20-minute walk or bike ride to give your eyes a break."
            )
        }

        return GuidanceSuggestion(
            conversationStarters: [
                "What were you watching, \(name)?",
                "What did you like or not like about it?",
                "Would you watch something like that again?"
            ],
            offlineActivity: "Let's take a 15-minute screen break together."
        )
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
