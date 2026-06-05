//
//  SuggestionHistoryEntry.swift
//  team-10-c3
//

import Foundation

struct SuggestionHistoryEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let date: Date
    let suggestion: String
    let detail: String
    let outcome: String

    init(
        id: UUID = UUID(),
        date: Date,
        suggestion: String,
        detail: String,
        outcome: String
    ) {
        self.id = id
        self.date = date
        self.suggestion = suggestion
        self.detail = detail
        self.outcome = outcome
    }

    var dateLabel: String {
        Self.dateLabelFormatter.string(from: date)
    }

    private static let dateLabelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, EEEE"
        return formatter
    }()
}
