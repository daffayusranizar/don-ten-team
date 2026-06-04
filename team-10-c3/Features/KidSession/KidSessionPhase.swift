//
//  KidSessionPhase.swift
//  team-10-c3
//

import Foundation

/// High-level kid-session flow — one phase at a time so prior session data cannot leak.
enum KidSessionPhase: Equatable {
    case idle
    case active(ActiveKidSession)
    case finished(FinishedKidSession)
}

/// Screen Time session in progress.
struct ActiveKidSession: Equatable {
    let sessionId: UUID
    let includesScreenRecording: Bool
    let recordingBroadcastConfirmed: Bool
}

/// Session ended; analysis may still be running for this id only.
struct FinishedKidSession: Equatable {
    let sessionId: UUID
    let includesScreenRecording: Bool
}

extension KidSessionPhase {
    var activeSessionId: UUID? {
        if case .active(let session) = self { return session.sessionId }
        return nil
    }

    var finishedSessionId: UUID? {
        if case .finished(let session) = self { return session.sessionId }
        return nil
    }

    var isActive: Bool {
        if case .active = self { return true }
        return false
    }

    var isFinished: Bool {
        if case .finished = self { return true }
        return false
    }
}
