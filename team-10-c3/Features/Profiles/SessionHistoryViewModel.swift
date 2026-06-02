//
//  SessionHistoryViewModel.swift
//  team-10-c3
//

import Foundation
import Observation

@Observable
@MainActor
final class SessionHistoryViewModel {
    private let suggestionHistoryRepository: SuggestionHistoryRepository

    var selectedTab: HistoryTab = .suggestion
    var selectedMonth: String
    private(set) var monthOptions: [String] = []
    private(set) var suggestionEntries: [SuggestionHistoryEntry] = []
    var loadError: String?

    init(suggestionHistoryRepository: SuggestionHistoryRepository) {
        self.suggestionHistoryRepository = suggestionHistoryRepository
        self.selectedMonth = suggestionHistoryRepository.availableMonths().first ?? ""
        reload()
    }

    var screenTimePlaceholderMessage: String {
        "Screen time history for \(selectedMonth) will appear here."
    }

    func selectTab(_ tab: HistoryTab) {
        selectedTab = tab
    }

    func selectMonth(_ month: String) {
        guard month != selectedMonth else { return }
        selectedMonth = month
        reloadSuggestionEntries()
    }

    func reload() {
        monthOptions = suggestionHistoryRepository.availableMonths()
        if !monthOptions.contains(selectedMonth), let firstMonth = monthOptions.first {
            selectedMonth = firstMonth
        }
        reloadSuggestionEntries()
    }

    private func reloadSuggestionEntries() {
        do {
            suggestionEntries = try suggestionHistoryRepository.fetchEntries(for: selectedMonth)
            loadError = nil
        } catch {
            suggestionEntries = []
            loadError = error.localizedDescription
        }
    }
}
