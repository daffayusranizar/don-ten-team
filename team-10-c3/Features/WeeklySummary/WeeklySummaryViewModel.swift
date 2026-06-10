//
//  WeeklySummaryViewModel.swift
//  team-10-c3
//

import Foundation
import Observation

@Observable
@MainActor
final class WeeklySummaryViewModel {
    private let insightService: UsageInsightService
    private var refreshTask: Task<Void, Never>?

    var selectedPeriod: Period = .daily
    private(set) var report: UsageInsightReport?
    private(set) var isLoading = false
    /// True while reloading when a report is already on screen (regenerate / tab refresh).
    private(set) var isRefreshing = false
    private(set) var emptyMessage: String?
    /// Bumped when weekly suggestion + saved try response are reset (e.g. debug regenerate).
    private(set) var suggestionTryResetGeneration: UInt64 = 0

    init(
        sessionRepository: SessionRepository,
        sessionAnalysisStore: SessionAnalysisStore,
        screenTimeService: ScreenTimeUsageProviding,
        familyControlsAuth: FamilyControlsAuthProviding
    ) {
        insightService = UsageInsightService(
            sessionRepository: sessionRepository,
            sessionAnalysisStore: sessionAnalysisStore,
            screenTimeService: screenTimeService,
            familyControlsAuth: familyControlsAuth
        )
    }

    func refresh(childId: UUID?, child: Child?, forceRegenerateWeekly: Bool = false) {
        refreshTask?.cancel()

        guard let childId else {
            report = nil
            emptyMessage = "Select a child on the Dashboard to see usage insights."
            isLoading = false
            isRefreshing = false
            return
        }

        let keepVisibleReport = report != nil
        if keepVisibleReport {
            isRefreshing = true
            isLoading = false
        } else {
            isLoading = true
            isRefreshing = false
        }
        emptyMessage = nil

        refreshTask = Task {
            let preserveReportOnFailure = keepVisibleReport
            defer {
                if !Task.isCancelled {
                    isLoading = false
                    isRefreshing = false
                }
            }

            do {
                if let built = try await insightService.buildReport(
                    childId: childId,
                    child: child,
                    period: selectedPeriod,
                    forceRegenerateWeekly: forceRegenerateWeekly
                ) {
                    guard !Task.isCancelled else { return }
                    report = built
                    emptyMessage = nil
                } else {
                    guard !Task.isCancelled else { return }
                    if !preserveReportOnFailure {
                        report = nil
                        emptyMessage = emptyStateMessage(for: selectedPeriod)
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                if !preserveReportOnFailure {
                    report = nil
                    emptyMessage = "Could not load insights. Pull to refresh and try again."
                }
            }
        }
    }

    private func emptyStateMessage(for period: Period) -> String {
        switch period {
        case .daily:
            return "No analyzed sessions today yet. Complete a session with screen recording to see today's usage insight."
        case .weekly:
            return "No analyzed sessions this week yet. Complete sessions with screen recording to build a weekly insight."
        }
    }

    #if DEBUG
    /// Clears cached weekly output and regenerates summary + suggestion together (one LLM call).
    func refreshWeeklyGeneration(childId: UUID?, child: Child?) {
        guard selectedPeriod == .weekly, let childId else { return }
        let weekKey = WeeklyInsightFormatting.weekKey(referenceDate: Date(), calendar: .current)
        insightService.resetWeeklyGeneration(childId: childId, weekKey: weekKey)
        suggestionTryResetGeneration &+= 1
        refresh(childId: childId, child: child, forceRegenerateWeekly: true)
    }
    #endif
}
