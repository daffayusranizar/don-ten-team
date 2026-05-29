//
//  UsageCategorySegment.swift
//  team-10-c3
//

import SwiftUI

struct UsageCategorySegment: Identifiable, Equatable {
    let id: UUID
    let title: String
    let duration: TimeInterval
    let color: Color
    let systemImage: String

    init(
        id: UUID = UUID(),
        title: String,
        duration: TimeInterval,
        color: Color,
        systemImage: String
    ) {
        self.id = id
        self.title = title
        self.duration = duration
        self.color = color
        self.systemImage = systemImage
    }
}

// MARK: - Preview Data

extension UsageCategorySegment {
    static let previewData: [UsageCategorySegment] = [
        UsageCategorySegment(
            title: "Entertainment",
            duration: 9 * 3600 + 24 * 60,
            color: .usageEntertainment,
            systemImage: "tv.fill"
        ),
        UsageCategorySegment(
            title: "Education",
            duration: 6 * 3600 + 12 * 60,
            color: .usageEducation,
            systemImage: "book.fill"
        ),
        UsageCategorySegment(
            title: "Games",
            duration: 3 * 3600 + 12 * 60,
            color: .usageGames,
            systemImage: "gamecontroller.fill"
        )
    ]
}

// MARK: - Duration Formatting

enum DurationFormatting {
    static func hoursAndMinutes(_ interval: TimeInterval) -> String {
        let totalMinutes = max(0, Int(interval.rounded()) / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        var parts: [String] = []
        if hours > 0 {
            parts.append("\(hours) \(hours == 1 ? "hour" : "hours")")
        }
        if minutes > 0 {
            parts.append("\(minutes) \(minutes == 1 ? "minute" : "minutes")")
        }
        if parts.isEmpty {
            return "0 minutes"
        }
        return parts.joined(separator: " ")
    }
}
