//
//  SuggestionHistoryEntry.swift
//  team-10-c3
//

import Foundation

struct SuggestionHistoryEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let date: Date
    let suggestion: String
    let tried: Bool
    let followUpOptions: [String]
    let followUpSelection: String?
    let note: String

    init(
        id: UUID = UUID(),
        date: Date,
        suggestion: String,
        tried: Bool,
        followUpOptions: [String],
        followUpSelection: String?,
        note: String
    ) {
        self.id = id
        self.date = date
        self.suggestion = suggestion
        self.tried = tried
        self.followUpOptions = followUpOptions
        self.followUpSelection = followUpSelection
        self.note = note
    }

    var dateLabel: String {
        Self.dateLabelFormatter.string(from: date)
    }

    var detail: String { note }
    var outcome: String { followUpSelection ?? (tried ? "Tried" : "Skipped") }

    private static let dateLabelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, EEEE"
        return formatter
    }()
}
