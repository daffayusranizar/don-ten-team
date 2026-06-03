//
//  KidSessionViewModel.swift
//  team-10-c3
//
//  Created by Huy Tran on 26/05/26.
//
// [P1]

import Foundation
import Observation

@Observable
@MainActor
final class KidSessionViewModel {
    var selectedChild: Child?
    var durationMinutes: Int = 30
    var isSessionActive = false
    var isSessionComplete = false
    var remainingSeconds: Int = 0

    var youtubeAllowed = false
    var tiktokAllowed = false
    var instagramAllowed = false
    var mobileLegendsAllowed = false
    var candyCrushAllowed = false
    var pubgAllowed = false

    private var timerTask: Task<Void, Never>?

    let durationOptions = [15, 30, 45, 60]

    var formattedRemainingTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var canStartSession: Bool {
        selectedChild != nil && !isSessionActive
    }

    func syncSelectedChild(from profileViewModel: ProfileViewModel) {
        selectedChild = profileViewModel.selectedChild
    }

    func startSession() {
        guard selectedChild != nil else { return }

        remainingSeconds = durationMinutes * 60
        isSessionActive = true
        isSessionComplete = false
        timerTask?.cancel()

        timerTask = Task {
            while remainingSeconds > 0, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                remainingSeconds -= 1
            }

            if remainingSeconds <= 0, !Task.isCancelled {
                completeSession()
            }
        }
    }

    func endSessionEarly() {
        timerTask?.cancel()
        postStopNotification()
        completeSession()
    }

    private func postStopNotification() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            BroadcastConstants.stopBroadcastNotification,
            nil, nil, true
        )
    }

    func completeSession() {
        timerTask?.cancel()
        isSessionActive = false
        isSessionComplete = true
        remainingSeconds = 0
    }

    func resetAfterEndScreen() {
        isSessionComplete = false
    }
}
