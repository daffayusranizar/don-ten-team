//
//  SessionHistoryViewModel.swift
//  team-10-c3
//

import Foundation
import Observation

struct SessionHistoryEntry: Identifiable {
    let sessionId: UUID
    let analyzedAt: Date
    let result: PipelineResult?
    let errorMessage: String?

    var id: UUID { sessionId }

    var dateLabel: String {
        Self.dateLabelFormatter.string(from: analyzedAt)
    }

    var timeLabel: String {
        Self.timeLabelFormatter.string(from: analyzedAt)
    }

    var categoryLabel: String? {
        result?.dominantCategoryDisplay
    }

    var summaryPreview: String? {
        result?.summary
    }

    var screenCount: Int {
        result?.screens.count ?? 0
    }

    private static let dateLabelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, EEEE"
        return formatter
    }()

    private static let timeLabelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
}

@Observable
@MainActor
final class SessionHistoryViewModel {
    private let sessionAnalysisStore: SessionAnalysisStore?
    private var childId: UUID?

    var selectedMonth: String
    private(set) var monthOptions: [String] = []
    private(set) var sessionEntries: [SessionHistoryEntry] = []
    var loadError: String?

    init(sessionAnalysisStore: SessionAnalysisStore?) {
        self.sessionAnalysisStore = sessionAnalysisStore
        self.selectedMonth = ""
        reload()
    }

    func selectMonth(_ month: String) {
        guard month != selectedMonth else { return }
        selectedMonth = month
        reloadEntries()
    }

    func reload(for child: Child?) {
        childId = child?.id
        reloadMonthOptions(for: child)
        reloadEntries()
    }

    func reload() {
        reload(for: nil)
    }

    private func reloadMonthOptions(for child: Child?) {
        guard let child, let sessionAnalysisStore else {
            monthOptions = []
            selectedMonth = ""
            return
        }

        monthOptions = sessionAnalysisStore.availableMonths(for: child.id)
        if !monthOptions.contains(selectedMonth), let firstMonth = monthOptions.first {
            selectedMonth = firstMonth
        }
    }

    private func reloadEntries() {
        guard let childId, let sessionAnalysisStore else {
            sessionEntries = []
            return
        }

        let monthFilter = selectedMonth.isEmpty ? nil : selectedMonth
        let items = sessionAnalysisStore.fetchHistory(for: childId, month: monthFilter)

        sessionEntries = items.map { item in
            SessionHistoryEntry(
                sessionId: item.sessionId,
                analyzedAt: item.analyzedAt,
                result: item.cacheEntry.result,
                errorMessage: item.cacheEntry.errorMessage
            )
        }
        loadError = nil
    }
}
