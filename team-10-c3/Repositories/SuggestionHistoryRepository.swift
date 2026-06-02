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

    init(entriesByMonth: [String: [SuggestionHistoryEntry]] = [:]) {
        self.entriesByMonth = entriesByMonth
    }

    func availableMonths() -> [String] {
        entriesByMonth.keys.sorted(by: >)
    }

    func fetchEntries(for month: String) throws -> [SuggestionHistoryEntry] {
        entriesByMonth[month] ?? []
    }
}

#if DEBUG
extension InMemorySuggestionHistoryRepository {
    static var preview: InMemorySuggestionHistoryRepository {
        InMemorySuggestionHistoryRepository(entriesByMonth: [
            "May 2026": [
                SuggestionHistoryEntry(
                    date: previewDate(year: 2026, month: 5, day: 1),
                    suggestion: "Watch one video together and ask what he found interesting.",
                    detail: "Showed a cooking video, talked for 20 min",
                    outcome: "Opened up and talked"
                )
            ]
        ])
    }

    private static func previewDate(year: Int, month: Int, day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }
}
#endif
