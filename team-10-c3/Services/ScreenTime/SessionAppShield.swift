import FamilyControls
import Foundation
import ManagedSettings

enum SessionAppShieldError: LocalizedError {
    case notAuthorized
    case requiresIOS264

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Screen Time access is required to limit apps during a session."
        case .requiresIOS264:
            return "App blocking requires iOS 26.4 or later on this device."
        }
    }
}

/// Blocks opening any installed app except TikTok, YouTube, and this app while a session is active.
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

        let hostBundle = Bundle.main.bundleIdentifier?.lowercased() ?? ""
        let installed = try await FamilyActivityData.shared.installedApplications

        var allowed = Set<ApplicationToken>()
        var blocked = Set<ApplicationToken>()

        for app in installed {
            guard let token = app.token,
                  let bundleId = app.bundleIdentifier,
                  !bundleId.isEmpty else { continue }

            if MonitoredAppsFilter.includes(bundleId: bundleId) {
                allowed.insert(token)
                continue
            }
            if bundleId.lowercased() == hostBundle {
                continue
            }
            blocked.insert(token)
        }

        SessionShieldStore.persistAndApply(allowed: allowed, blocked: blocked)

        AgentDebugLog.log(
            hypothesisId: "C",
            location: "SessionAppShield.applyAllowlist",
            message: "session app shield applied",
            data: [
                "allowedCount": String(allowed.count),
                "blockedCount": String(blocked.count),
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
