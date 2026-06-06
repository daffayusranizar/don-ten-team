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
    /// True when app blocking / session start requires Screen Time approval.
    var needsPermissionPrompt: Bool { get }
    /// True when basic Screen Time is granted but per-app usage data is not (charts only).
    var needsUsagePermissionPrompt: Bool { get }
    /// Usage charts unavailable because status is `approved` (not `approvedWithDataAccess`) — re-prompting won't help.
    var isUsageDataEntitlementMissing: Bool { get }
    /// User turned off Screen Time for Kiddly in Settings — re-prompting won't help.
    var isAuthorizationDenied: Bool { get }
    func refreshAuthorizationStatus()
    func requestAuthorization() async throws
    /// App blocking and session monitoring — does not require usage-data access.
    func ensureSessionAuthorization() async throws
    /// Per-app usage charts — requires `approvedWithDataAccess` on iOS 26.4+.
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
    private(set) var isAuthorizationDenied = false
    private(set) var authorizationStatusDescription = "unknown"

    init() {
        refreshAuthorizationStatus()
    }

    func refreshAuthorizationStatus() {
        let status = AuthorizationCenter.shared.authorizationStatus
        authorizationStatusDescription = String(describing: status)

        switch status {
        case .approved:
            isAuthorizationDenied = false
            isAuthorized = true
            if #available(iOS 26.4, *) {
                hasUsageDataAccess = false
            } else {
                hasUsageDataAccess = true
            }
        case .approvedWithDataAccess:
            isAuthorizationDenied = false
            isAuthorized = true
            hasUsageDataAccess = true
        case .denied:
            isAuthorizationDenied = true
            isAuthorized = false
            hasUsageDataAccess = false
        case .notDetermined:
            isAuthorizationDenied = false
            isAuthorized = false
            hasUsageDataAccess = false
        @unknown default:
            isAuthorizationDenied = false
            isAuthorized = false
            hasUsageDataAccess = false
        }
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
        !isAuthorized
    }

    var needsUsagePermissionPrompt: Bool {
        isAuthorized && !hasUsageDataAccess
    }

    /// On iOS 26.4+, `approved` without data access usually means the distribution
    /// profile lacks `com.apple.developer.family-controls.app-and-website-usage`.
    /// Calling `requestAuthorization()` again does not show a separate user toggle.
    var isUsageDataEntitlementMissing: Bool {
        guard isAuthorized, !hasUsageDataAccess else { return false }
        if #available(iOS 26.4, *) {
            return AuthorizationCenter.shared.authorizationStatus == .approved
        }
        return false
    }

    func permissionAlertTitle() -> String {
        if missingPermissions.contains(.familyControlsNotApproved) {
            return "Screen Time required"
        }
        return "App usage access needed"
    }

    func permissionAlertMessage() -> String {
        if isAuthorizationDenied {
            return """
            Screen Time access for Kiddly is turned off.

            Open Settings → Screen Time → Apps with Screen Time Access, enable Kiddly, then return here.
            """
        }
        if missingPermissions.contains(.familyControlsNotApproved) {
            return """
            Kiddly needs Screen Time permission to run parent sessions:

            • Block all apps except TikTok and YouTube
            • Show estimated app usage on the dashboard

            Tap Continue for Apple’s permission screen, then allow access.
            """
        }
        return """
            Screen Time is on, but TikTok/YouTube usage charts are not available on this build.

            This is not a setting you can turn on in the app — Apple must approve \
            “Family Controls App And Website Usage” for your TestFlight/App Store build. \
            Parent’s Access should show status `approvedWithDataAccess` when it works.

            Sessions and app blocking still work with basic Screen Time access.
            """
    }

    func sessionPermissionBlockedMessage() -> String? {
        guard !canBlockAppsDuringSession else {
            if !canRecordSessionUsage {
                if isUsageDataEntitlementMissing {
                    return "Usage charts need Apple’s App & Website Usage entitlement on this build (status: approved). Sessions still work."
                }
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
        if !isAuthorized {
            // AuthorizationCenter can lag briefly after the system sheet dismisses.
            try await Task.sleep(for: .milliseconds(350))
            refreshAuthorizationStatus()
        }
    }

    func ensureSessionAuthorization() async throws {
        refreshAuthorizationStatus()
        if isAuthorizationDenied {
            throw FamilyControlsAuthError.notAuthorized(status: authorizationStatusDescription)
        }
        if !isAuthorized {
            try await requestAuthorization()
            refreshAuthorizationStatus()
        }
        guard isAuthorized else {
            throw FamilyControlsAuthError.notAuthorized(status: authorizationStatusDescription)
        }
    }

    func ensureUsageAuthorization() async throws {
        try await ensureSessionAuthorization()
        refreshAuthorizationStatus()
        guard !hasUsageDataAccess else { return }

        // First authorization may grant both; re-prompting after `approved` never upgrades.
        if !isAuthorized {
            try await requestAuthorization()
            refreshAuthorizationStatus()
        }

        guard hasUsageDataAccess else {
            throw FamilyControlsAuthError.usageAccessNotGranted(
                status: authorizationStatusDescription
            )
        }
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
    var needsUsagePermissionPrompt = false
    var isUsageDataEntitlementMissing = false
    var isAuthorizationDenied = false

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
        needsUsagePermissionPrompt = false
    }

    func ensureSessionAuthorization() async throws {
        try await requestAuthorization()
    }

    func ensureUsageAuthorization() async throws {
        try await ensureSessionAuthorization()
    }
}
