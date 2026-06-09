import FamilyControls
import Foundation
import ManagedSettings

enum SessionAppShieldError: LocalizedError, Equatable {
    case notAuthorized
    case requiresIOS264
    case appsNotSelected

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Screen Time access is required to limit apps during a session."
        case .requiresIOS264:
            return "App blocking requires iOS 26.4 or later on this device."
        case .appsNotSelected:
            return """
            Choose TikTok and YouTube in Parent's Access → Allowed Apps before starting a session.
            """
        }
    }
}

/// Blocks every app except parent-selected allowlist tokens while a session is active.
@MainActor
enum SessionAppShield {
    static func applyAllowlist() async throws {
        guard isFamilyControlsAuthorized() else {
            throw SessionAppShieldError.notAuthorized
        }
        guard #available(iOS 26.4, *) else {
            AgentDebugLog.log(
                hypothesisId: "C",
                location: "SessionAppShield.applyAllowlist",
                message: "app shield skipped below iOS 26.4",
                data: [:]
            )
            return
        }

        let allowed = FamilyActivitySelectionStore.allowedApplicationTokensForShields()
        guard !allowed.isEmpty else {
            AgentDebugLog.log(
                hypothesisId: "C",
                location: "SessionAppShield.applyAllowlist",
                message: "no picker tokens — shield skipped",
                data: ["tokenSource": "picker"]
            )
            throw SessionAppShieldError.appsNotSelected
        }

        SessionShieldStore.persistAndApply(allowed: allowed, blocked: [])

        AgentDebugLog.log(
            hypothesisId: "C",
            location: "SessionAppShield.applyAllowlist",
            message: "session app shield applied",
            data: [
                "tokenSource": "picker",
                "allowedCount": String(allowed.count),
                "blockedCount": "0",
            ]
        )
    }

    static func clear() {
        SessionShieldStore.clear()
        AgentDebugLog.log(
            hypothesisId: "C",
            location: "SessionAppShield.clear",
            message: "session app shield cleared",
            data: [:]
        )
    }

    private static func isFamilyControlsAuthorized() -> Bool {
        let status = AuthorizationCenter.shared.authorizationStatus
        if #available(iOS 26.4, *) {
            return status == .approved || status == .approvedWithDataAccess
        }
        return status == .approved
    }
}
