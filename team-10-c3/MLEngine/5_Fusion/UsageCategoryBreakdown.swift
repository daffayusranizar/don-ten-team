import Foundation
import SwiftUI

/// Chart buckets shown on the Insight dashboard (aligned with pipeline classifier labels).
public enum UsageInsightChartCategory: String, CaseIterable, Codable {
    case educational = "Educational"
    case entertainment = "Entertainment"
    case commercial = "Commercial"

    var color: Color {
        switch self {
        case .educational: .usageEducation
        case .entertainment: .usageEntertainment
        case .commercial: .usageGames
        }
    }

    var displayOrder: Int {
        switch self {
        case .educational: 0
        case .entertainment: 1
        case .commercial: 2
        }
    }

    static func fromPipelineLabel(_ label: String) -> UsageInsightChartCategory {
        let normalized = label.lowercased()
        if normalized.contains("educational") {
            return .educational
        }
        if normalized.contains("commercial") {
            return .commercial
        }
        if normalized.contains("entertainment") {
            return .entertainment
        }
        return .entertainment
    }
}

public struct UsageCategoryBreakdown: Codable, Equatable, Sendable {
    public struct Item: Codable, Equatable, Sendable, Identifiable {
        public var id: String { name }
        public let name: String
        public let frameCount: Int
        public let percentage: Int
    }

    public let items: [Item]

    public static let empty = UsageCategoryBreakdown(items: [])

    public var isEmpty: Bool {
        items.isEmpty || items.allSatisfy { $0.frameCount == 0 }
    }

    /// Top chart bucket by frame count (e.g. "Educational").
    public var dominantCategoryName: String? {
        items.first?.name
    }

    /// Parent-facing label with share of session, e.g. "Educational · 67%".
    public var dominantDisplayLabel: String? {
        guard let top = items.first else { return nil }
        return "\(top.name) · \(top.percentage)%"
    }

    public static func from(timeline: [FrameClassificationSummary], intervalSeconds: Double = 3.0) -> UsageCategoryBreakdown {
        fromScreens(
            timeline.map { ScreenLike(label: $0.label) },
            intervalSeconds: intervalSeconds
        )
    }

    static func from(screens: [StoredScreenBreakdown], intervalSeconds: Double = 3.0) -> UsageCategoryBreakdown {
        fromScreens(
            screens.map { ScreenLike(label: $0.categoryLabel) },
            intervalSeconds: intervalSeconds
        )
    }

    public func merged(with other: UsageCategoryBreakdown) -> UsageCategoryBreakdown {
        var counts: [String: Int] = [:]
        for item in items + other.items {
            guard UsageInsightChartCategory(rawValue: item.name) != nil else { continue }
            counts[item.name, default: 0] += item.frameCount
        }
        return Self.fromCounts(counts)
    }

    // MARK: - Private

    private struct ScreenLike {
        let label: String
    }

    private static func fromScreens(_ screens: [ScreenLike], intervalSeconds: Double) -> UsageCategoryBreakdown {
        guard !screens.isEmpty else { return .empty }

        var counts: [String: Int] = [:]
        for screen in screens {
            let bucket = UsageInsightChartCategory.fromPipelineLabel(screen.label).rawValue
            counts[bucket, default: 0] += 1
        }
        _ = intervalSeconds
        return fromCounts(counts)
    }

    private static func fromCounts(_ counts: [String: Int]) -> UsageCategoryBreakdown {
        let total = counts.values.reduce(0, +)
        guard total > 0 else { return .empty }

        let items = counts
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                let leftOrder = UsageInsightChartCategory(rawValue: lhs.key)?.displayOrder ?? 99
                let rightOrder = UsageInsightChartCategory(rawValue: rhs.key)?.displayOrder ?? 99
                return leftOrder < rightOrder
            }
            .map { name, count in
                Item(
                    name: name,
                    frameCount: count,
                    percentage: Int((Double(count) / Double(total) * 100).rounded())
                )
            }

        return UsageCategoryBreakdown(items: items)
    }
}

enum InsightProseBuilder {
    static func dailySummary(totalSeconds: Int, breakdown: UsageCategoryBreakdown) -> String {
        guard totalSeconds > 0 else {
            return "No screen time was recorded today yet."
        }

        let duration = DurationFormatting.verbose(seconds: totalSeconds).lowercased()
        guard !breakdown.isEmpty else {
            return "Today, your child spent \(duration) on screen time."
        }

        let ranked = breakdown.items
        let primary = ranked[0]
        if ranked.count == 1 {
            return "Today, your child spent \(duration) on screen time, focused on \(primary.name.lowercased()) content."
        }

        let secondary = ranked[1]
        return """
        Today, your child spent \(duration) on screen time, with most activity focused on \(primary.name.lowercased()) content and a smaller portion on \(secondary.name.lowercased()).
        """
    }

    static func weeklySummary(totalSeconds: Int, breakdown: UsageCategoryBreakdown) -> String {
        guard totalSeconds > 0 else {
            return "No screen time was recorded this week yet."
        }

        let duration = DurationFormatting.verbose(seconds: totalSeconds).lowercased()
        guard breakdown.items.count >= 2 else {
            if let only = breakdown.items.first {
                return "This week, your child spent a total of \(duration) on screen time, mostly on \(only.name.lowercased()) content."
            }
            return "This week, your child spent a total of \(duration) on screen time."
        }

        let primary = breakdown.items[0]
        let secondary = breakdown.items[1]
        return """
        This week, your child spent a total of \(duration) on screen time, with \(primary.percentage)% dedicated to \(primary.name.lowercased()) content and \(secondary.percentage)% to \(secondary.name.lowercased()). Their digital activity showed a healthy balance between learning and relaxation throughout the week.
        """
    }

    static let offlineActivityTeaser =
        "Explore the recommended offline activity that we already provide for you to do it with your child!"

    static func weeklySuggestion(from conversationStarters: [String]) -> String {
        if let starter = conversationStarters.first, !starter.isEmpty {
            return """
            Spend 15–20 minutes talking with your child about what they watched this week. For example: "\(starter)" These small conversations help you understand their interests while encouraging healthier screen habits.
            """
        }
        return """
        Spend 15–20 minutes talking with your child about what they watched this week — ask what they learned, which content made them happy, and if anything confused or surprised them. These small conversations can help parents better understand their child's interests while encouraging healthier and more mindful screen habits.
        """
    }
}
