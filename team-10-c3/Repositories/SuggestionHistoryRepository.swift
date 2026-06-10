//
//  SuggestionHistoryRepository.swift
//  team-10-c3
//

import Foundation
import SwiftData

struct WeeklySuggestionTryPayload: Equatable, Sendable {
    let childId: UUID
    let weekKey: String
    let suggestion: String
    let tried: Bool
    let followUpOptions: [String]
    let followUpSelection: String?
    let note: String?
}

@MainActor
protocol SuggestionHistoryRepository {
    func availableMonths(for childId: UUID?) -> [String]
    func fetchEntries(for month: String, childId: UUID?) throws -> [SuggestionHistoryEntry]
}

@MainActor
final class SwiftDataSuggestionHistoryRepository: SuggestionHistoryRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func availableMonths(for childId: UUID?) -> [String] {
        let records = fetchRecords(for: childId)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let months = records.map { formatter.string(from: $0.savedAt) }
        return Array(Set(months)).sorted(by: >)
    }

    func fetchEntries(for month: String, childId: UUID?) throws -> [SuggestionHistoryEntry] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        return fetchRecords(for: childId)
            .filter { formatter.string(from: $0.savedAt) == month }
            .map { record in
                SuggestionHistoryEntry(
                    id: record.id,
                    date: record.savedAt,
                    suggestion: record.suggestion,
                    tried: record.tried,
                    followUpOptions: Self.decodeStringArray(record.followUpOptionsJSON),
                    followUpSelection: record.followUpSelection,
                    note: record.note ?? ""
                )
            }
    }

    private func fetchRecords(for childId: UUID?) -> [WeeklySuggestionTryRecord] {
        if let childId {
            let childIdValue = childId
            var descriptor = FetchDescriptor<WeeklySuggestionTryRecord>(
                predicate: #Predicate { $0.childId == childIdValue },
                sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
            )
            return (try? modelContext.fetch(descriptor)) ?? []
        }

        var descriptor = FetchDescriptor<WeeklySuggestionTryRecord>(
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private static func decodeStringArray(_ json: String) -> [String] {
        guard let data = json.data(using: .utf8),
              let values = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return values
    }
}

@MainActor
final class InMemorySuggestionHistoryRepository: SuggestionHistoryRepository {
    private let entriesByMonth: [String: [SuggestionHistoryEntry]]

    init(entriesByMonth: [String: [SuggestionHistoryEntry]] = [:]) {
        self.entriesByMonth = entriesByMonth
    }

    func availableMonths(for childId: UUID?) -> [String] {
        _ = childId
        return entriesByMonth.keys.sorted(by: >)
    }

    func fetchEntries(for month: String, childId: UUID?) throws -> [SuggestionHistoryEntry] {
        _ = childId
        return entriesByMonth[month] ?? []
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
                    tried: true,
                    followUpOptions: WeeklyInsightOutput.defaultFollowUpOptions,
                    followUpSelection: "Opened up and talked",
                    note: "Showed a cooking video, talked for 20 min"
                )
            ]
        ])
    }

    private static func previewDate(year: Int, month: Int, day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }
}
#endif
