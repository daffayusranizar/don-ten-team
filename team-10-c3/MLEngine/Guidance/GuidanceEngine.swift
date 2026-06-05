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
        let age = child?.currentAge ?? 8
        _ = timeline

        if category.contains("Educational") {
            return GuidanceSuggestion(
                offlineActivity: age < 8
                    ? "Let's draw or build something related to what you learned."
                    : "Let's look up one more fact about that topic together—in a book or safely online."
            )
        }

        if category.contains("Entertainment") {
            return GuidanceSuggestion(
                offlineActivity: age < 8
                    ? "Let's build a fort out of blankets!"
                    : "Let's go for a 20-minute walk or bike ride to give your eyes a break."
            )
        }

        return GuidanceSuggestion(
            offlineActivity: "Let's take a 15-minute screen break together."
        )
    }
}
