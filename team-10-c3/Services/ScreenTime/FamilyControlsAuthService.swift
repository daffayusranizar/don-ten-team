import Foundation
import FamilyControls
import Observation

enum ScreenTimePermissionGap: Equatable {
    case familyControlsNotApproved
    case usageDataNotGranted
}

@MainActor
protocol FamilyControlsAuthProviding: AnyObject {
    var isAuthorized: Bool { get }
    var hasUsageDataAccess: Bool { get }
    var canBlockAppsDuringSession: Bool { get }
    /// Per-app session usage charts require usage data access.
    var canRecordSessionUsage: Bool { get }
    var authorizationStatusDescription: String { get }
    var missingPermissions: [ScreenTimePermissionGap] { get }
    var needsPermissionPrompt: Bool { get }
    func refreshAuthorizationStatus()
    func requestAuthorization() async throws
    func ensureSessionAuthorization() async throws
    /// Shows the system Screen Time permission sheet if usage data access is not granted yet.
    func ensureUsageAuthorization() async throws
    func permissionAlertTitle() -> String
    func permissionAlertMessage() -> String
    /// User-facing reason when session cannot start; nil when allowed.
    func sessionPermissionBlockedMessage() -> String?
    /// @deprecated alias — use `sessionPermissionBlockedMessage()`
    func recordingBlockedMessage() -> String?
}

enum FamilyControlsAuthError: LocalizedError {
    case notAuthorized(status: String)
    case usageAccessNotGranted(status: String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized(let status):
            return "Screen Time access was not granted (status: \(status)). " +
                "Open Settings → Screen Time and allow Kiddly, or tap Enable in Parent’s Access."
        case .usageAccessNotGranted(let status):
            return ScreenTimeFetchError.missingUsageDataAccess(status: status).localizedDescription
        }
    }
}

@Observable
@MainActor
final class FamilyControlsAuthService: FamilyControlsAuthProviding {
    private(set) var isAuthorized = false
    private(set) var hasUsageDataAccess = false
    private(set) var authorizationStatusDescription = "unknown"

    init() {
        refreshAuthorizationStatus()
    }

    func refreshAuthorizationStatus() {
        let status = AuthorizationCenter.shared.authorizationStatus
        authorizationStatusDescription = String(describing: status)
        if #available(iOS 26.4, *) {
            hasUsageDataAccess = status == .approvedWithDataAccess
        } else {
            hasUsageDataAccess = status == .approved
        }
        isAuthorized = status == .approved || hasUsageDataAccess
    }

    var canBlockAppsDuringSession: Bool {
        isAuthorized
    }

    var canRecordSessionUsage: Bool {
        hasUsageDataAccess
    }

    var missingPermissions: [ScreenTimePermissionGap] {
        var gaps: [ScreenTimePermissionGap] = []
        if !isAuthorized {
            gaps.append(.familyControlsNotApproved)
        } else if !hasUsageDataAccess {
            gaps.append(.usageDataNotGranted)
        }
        return gaps
    }

    var needsPermissionPrompt: Bool {
        !missingPermissions.isEmpty
    }

    func permissionAlertTitle() -> String {
        if missingPermissions.contains(.familyControlsNotApproved) {
            return "Screen Time required"
        }
        return "App usage access needed"
    }

    func permissionAlertMessage() -> String {
        if missingPermissions.contains(.familyControlsNotApproved) {
            return """
            Kiddly needs Screen Time permission to run parent sessions:

            • Block all apps except TikTok and YouTube
            • Show estimated app usage on the dashboard

            Tap Continue for Apple’s permission screen, then allow access.
            """
        }
        return """
            Screen Time is on, but per-app usage data is not available yet.

            Tap Continue and allow App & Website Usage so Kiddly can show TikTok and YouTube time. \
            Sessions can still block other apps once basic Screen Time access is granted.
            """
    }

    func sessionPermissionBlockedMessage() -> String? {
        guard !canBlockAppsDuringSession else {
            if !canRecordSessionUsage {
                return "Session started, but usage charts need App & Website Usage. " +
                    "Open Parent’s Access → Allow Screen Time usage."
            }
            return nil
        }
        return permissionAlertMessage()
    }

    func recordingBlockedMessage() -> String? {
        sessionPermissionBlockedMessage()
            ?? (canRecordSessionUsage ? nil : permissionAlertMessage())
    }

    func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        refreshAuthorizationStatus()
    }

    func ensureSessionAuthorization() async throws {
        refreshAuthorizationStatus()
        if !isAuthorized {
            try await requestAuthorization()
            refreshAuthorizationStatus()
        }
        guard isAuthorized else {
            throw FamilyControlsAuthError.notAuthorized(status: authorizationStatusDescription)
        }

        if !hasUsageDataAccess {
            try await requestAuthorization()
            refreshAuthorizationStatus()
        }
        guard hasUsageDataAccess else {
            throw FamilyControlsAuthError.usageAccessNotGranted(
                status: authorizationStatusDescription
            )
        }
    }

    func ensureUsageAuthorization() async throws {
        try await ensureSessionAuthorization()
    }
}

@Observable
@MainActor
final class PreviewFamilyControlsAuthService: FamilyControlsAuthProviding {
    var isAuthorized = true
    var hasUsageDataAccess = true
    var canBlockAppsDuringSession = true
    var canRecordSessionUsage = true
    var authorizationStatusDescription = "approvedWithDataAccess"
    var missingPermissions: [ScreenTimePermissionGap] = []
    var needsPermissionPrompt = false

    func refreshAuthorizationStatus() {}

    func permissionAlertTitle() -> String { "Screen Time required" }

    func permissionAlertMessage() -> String { "Preview: permission granted." }

    func sessionPermissionBlockedMessage() -> String? { nil }

    func recordingBlockedMessage() -> String? { nil }

    func requestAuthorization() async throws {
        isAuthorized = true
        hasUsageDataAccess = true
        canBlockAppsDuringSession = true
        canRecordSessionUsage = true
        missingPermissions = []
        needsPermissionPrompt = false
    }

    func ensureSessionAuthorization() async throws {
        try await requestAuthorization()
    }

    func ensureUsageAuthorization() async throws {
        try await ensureSessionAuthorization()
    }
}
