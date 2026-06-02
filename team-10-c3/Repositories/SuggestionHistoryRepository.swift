//
//  SuggestionHistoryRepository.swift
//  team-10-c3
//

import Foundation

@MainActor
protocol SuggestionHistoryRepository {
    func availableMonths() -> [String]
    func fetchEntries(for month: String) throws -> [SuggestionHistoryEntry]
}

@MainActor
final class InMemorySuggestionHistoryRepository: SuggestionHistoryRepository {
    private let entriesByMonth: [String: [SuggestionHistoryEntry]]

    init(entriesByMonth: [String: [SuggestionHistoryEntry]]? = nil) {
        self.entriesByMonth = entriesByMonth ?? Self.previewEntriesByMonth
    }

    func availableMonths() -> [String] {
        entriesByMonth.keys.sorted(by: >)
    }

    func fetchEntries(for month: String) throws -> [SuggestionHistoryEntry] {
        entriesByMonth[month] ?? []
    }
}

private extension InMemorySuggestionHistoryRepository {
    static let previewEntriesByMonth: [String: [SuggestionHistoryEntry]] = [
        "May 2026": [
            SuggestionHistoryEntry(
                date: previewDate(year: 2026, month: 5, day: 1),
                suggestion: "Watch one video together and ask what he found interesting.",
                detail: "Raka showed a cooking video, talked for 20 min",
                outcome: "Opened up and talked"
            ),
            SuggestionHistoryEntry(
                date: previewDate(year: 2026, month: 5, day: 1),
                suggestion: "Watch one video together and ask what he found interesting.",
                detail: "Too busy that week",
                outcome: "Didn't want to"
            ),
            SuggestionHistoryEntry(
                date: previewDate(year: 2026, month: 5, day: 1),
                suggestion: "Watch one video together and ask what he found interesting.",
                detail: "Taught Mum how planes stay in the air",
                outcome: "Led to a longer conversation"
            ),
            SuggestionHistoryEntry(
                date: previewDate(year: 2026, month: 5, day: 1),
                suggestion: "Watch one video together and ask what he found interesting.",
                detail: "Taught Mum how planes stay in the air",
                outcome: "Enjoyed it, nto much talking"
            )
        ],
        "April 2026": [],
        "March 2026": []
    ]

    static func previewDate(year: Int, month: Int, day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }
}
