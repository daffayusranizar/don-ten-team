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

// MARK: - SwiftUI preview only (not used in production UI)

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
    /// Compact labels: `45S`, `5M 30S`, `1H 5M 30S`
    static func compact(seconds rawSeconds: Int) -> String {
        let seconds = max(0, rawSeconds)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        var parts: [String] = []
        if hours > 0 {
            parts.append("\(hours)H")
        }
        if minutes > 0 {
            parts.append("\(minutes)M")
        }
        if secs > 0 || parts.isEmpty {
            parts.append("\(secs)S")
        }
        return parts.joined(separator: " ")
    }

    /// Readable labels: `45 Seconds`, `5 Minutes 30 Seconds`, `1 Hour 5 Minutes`
    static func verbose(seconds rawSeconds: Int) -> String {
        let seconds = max(0, rawSeconds)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        var parts: [String] = []
        if hours > 0 {
            parts.append("\(hours) Hour\(hours == 1 ? "" : "s")")
        }
        if minutes > 0 {
            parts.append("\(minutes) Minute\(minutes == 1 ? "" : "s")")
        }
        if secs > 0 {
            parts.append("\(secs) Second\(secs == 1 ? "" : "s")")
        }
        if parts.isEmpty {
            return "0 Seconds"
        }
        return parts.joined(separator: " ")
    }

    static func hoursAndMinutes(_ interval: TimeInterval) -> String {
        compact(seconds: Int(interval.rounded()))
    }
}
