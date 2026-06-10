//
//  SuggestionHistoryViewModel.swift
//  team-10-c3
//

import Foundation
import Observation

@Observable
@MainActor
final class SuggestionHistoryViewModel {
    private let repository: SuggestionHistoryRepository
    private var childId: UUID?

    var selectedMonth: String = ""
    private(set) var monthOptions: [String] = []
    private(set) var entries: [SuggestionHistoryEntry] = []
    var loadError: String?

    init(repository: SuggestionHistoryRepository) {
        self.repository = repository
    }

    func selectMonth(_ month: String) {
        guard month != selectedMonth else { return }
        selectedMonth = month
        reloadEntries()
    }

    func reload(for child: Child?) {
        childId = child?.id
        reloadMonthOptions()
        reloadEntries()
    }

    private func reloadMonthOptions() {
        guard let childId else {
            monthOptions = []
            selectedMonth = ""
            return
        }

        monthOptions = repository.availableMonths(for: childId)
        if !monthOptions.contains(selectedMonth), let firstMonth = monthOptions.first {
            selectedMonth = firstMonth
        } else if monthOptions.isEmpty {
            selectedMonth = ""
        }
    }

    private func reloadEntries() {
        guard let childId, !selectedMonth.isEmpty else {
            entries = []
            return
        }

        do {
            entries = try repository.fetchEntries(for: selectedMonth, childId: childId)
            loadError = nil
        } catch {
            entries = []
            loadError = error.localizedDescription
        }
    }
}
