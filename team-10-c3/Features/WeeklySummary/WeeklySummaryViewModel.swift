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
    private(set) var emptyMessage: String?

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

    func refresh(childId: UUID?, child: Child?) {
        refreshTask?.cancel()

        guard let childId else {
            report = nil
            emptyMessage = "Select a child on the Dashboard to see usage insights."
            isLoading = false
            return
        }

        isLoading = true
        emptyMessage = nil

        refreshTask = Task {
            defer {
                if !Task.isCancelled {
                    isLoading = false
                }
            }

            do {
                if let built = try await insightService.buildReport(
                    childId: childId,
                    child: child,
                    period: selectedPeriod
                ) {
                    guard !Task.isCancelled else { return }
                    report = built
                    emptyMessage = nil
                } else {
                    guard !Task.isCancelled else { return }
                    report = nil
                    emptyMessage = emptyStateMessage(for: selectedPeriod)
                }
            } catch {
                guard !Task.isCancelled else { return }
                report = nil
                emptyMessage = "Could not load insights. Pull to refresh and try again."
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
}
