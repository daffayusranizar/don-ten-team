//
//  SessionHistoryViewModel.swift
//  team-10-c3
//

import Foundation
import Observation

struct ScreenTimeHistoryEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let date: Date
    let totalSeconds: Int
    let topAppName: String

    var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, EEEE"
        return formatter.string(from: date)
    }

    var durationLabel: String {
        DurationFormatting.hoursAndMinutes(TimeInterval(totalSeconds))
    }
}

@Observable
@MainActor
final class SessionHistoryViewModel {
    private let suggestionHistoryRepository: SuggestionHistoryRepository
    private let sessionRepository: SessionRepository
    private var childId: UUID?

    var selectedTab: HistoryTab = .suggestion
    var selectedMonth: String
    private(set) var monthOptions: [String] = []
    private(set) var suggestionEntries: [SuggestionHistoryEntry] = []
    private(set) var screenTimeEntries: [ScreenTimeHistoryEntry] = []
    var loadError: String?

    init(
        suggestionHistoryRepository: SuggestionHistoryRepository,
        sessionRepository: SessionRepository
    ) {
        self.suggestionHistoryRepository = suggestionHistoryRepository
        self.sessionRepository = sessionRepository
        self.selectedMonth = suggestionHistoryRepository.availableMonths().first ?? ""
        reload()
    }

    func selectTab(_ tab: HistoryTab) {
        selectedTab = tab
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
        var months = suggestionHistoryRepository.availableMonths()
        if let child,
           let sessionMonths = try? sessionRepository.availableMonths(for: child.id) {
            months.append(contentsOf: sessionMonths)
        }
        monthOptions = Array(Set(months)).sorted(by: >)
        if !monthOptions.contains(selectedMonth), let firstMonth = monthOptions.first {
            selectedMonth = firstMonth
        }
    }

    private func reloadEntries() {
        reloadSuggestionEntries()
        reloadScreenTimeEntries()
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

    private func reloadScreenTimeEntries() {
        guard let childId else {
            screenTimeEntries = []
            return
        }

        do {
            let snapshots = try sessionRepository.fetchSnapshots(for: childId, month: selectedMonth)
            screenTimeEntries = snapshots.map { snapshot in
                ScreenTimeHistoryEntry(
                    id: snapshot.id,
                    date: snapshot.stopAt,
                    totalSeconds: snapshot.totalSeconds,
                    topAppName: snapshot.appUsageRows.first?.displayName ?? "Apps"
                )
            }
            loadError = nil
        } catch {
            screenTimeEntries = []
            loadError = error.localizedDescription
        }
    }
}
