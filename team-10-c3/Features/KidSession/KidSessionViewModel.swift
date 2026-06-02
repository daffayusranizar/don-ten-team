//
//  KidSessionViewModel.swift
//  team-10-c3
//

import Foundation
import Observation

@Observable
@MainActor
final class KidSessionViewModel {
    private let sessionCoordinator: SessionCoordinator

    var selectedChild: Child?

    let durationOptions: [Int]

    init(
        sessionCoordinator: SessionCoordinator,
        durationOptions: [Int] = [15, 30, 45, 60]
    ) {
        self.sessionCoordinator = sessionCoordinator
        self.durationOptions = durationOptions
    }

    var durationMinutes: Int {
        get { sessionCoordinator.durationMinutes }
        set { sessionCoordinator.durationMinutes = newValue }
    }

    var isSessionActive: Bool {
        sessionCoordinator.isSessionActive
    }

    var isSessionComplete: Bool {
        sessionCoordinator.isSessionComplete
    }

    var remainingSeconds: Int {
        sessionCoordinator.remainingSeconds
    }

    var formattedRemainingTime: String {
        sessionCoordinator.formattedRemainingTime
    }

    var canStartSession: Bool {
        selectedChild != nil && !isSessionActive
    }

    func syncSelectedChild(from profileViewModel: ProfileViewModel) {
        selectedChild = profileViewModel.selectedChild
    }

    func startSession() {
        guard let child = selectedChild else { return }
        sessionCoordinator.startSession(child: child, durationMinutes: durationMinutes)
    }

    func endSessionEarly() {
        sessionCoordinator.endSessionEarly()
    }

    func completeSession() {
        sessionCoordinator.completeSessionFromTimer()
    }

    func resetAfterEndScreen() {
        sessionCoordinator.resetAfterEndScreen()
    }
}
