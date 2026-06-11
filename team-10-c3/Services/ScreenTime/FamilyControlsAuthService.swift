import Foundation
import FamilyControls
import Observation

enum ScreenTimePermissionGap: Equatable {
    case familyControlsNotApproved
}

@MainActor
protocol FamilyControlsAuthProviding: AnyObject {
    var isAuthorized: Bool { get }
    var canBlockAppsDuringSession: Bool { get }
    var authorizationStatusDescription: String { get }
    var missingPermissions: [ScreenTimePermissionGap] { get }
    var needsPermissionPrompt: Bool { get }
    var isAuthorizationDenied: Bool { get }
    func refreshAuthorizationStatus()
    func requestAuthorization() async throws
    func ensureSessionAuthorization() async throws
    func permissionAlertTitle() -> String
    func permissionAlertMessage() -> String
    func sessionPermissionBlockedMessage() -> String?
    /// @deprecated alias — use `sessionPermissionBlockedMessage()`
    func recordingBlockedMessage() -> String?
}

enum FamilyControlsAuthError: LocalizedError {
    case notAuthorized(status: String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized(let status):
            return "Screen Time access was not granted (status: \(status)). " +
                "Open Settings → Screen Time and allow Kiddly, or tap Enable in Parent's Access."
        }
    }
}

@Observable
@MainActor
final class FamilyControlsAuthService: FamilyControlsAuthProviding {
    private(set) var isAuthorized = false
    private(set) var isAuthorizationDenied = false
    private(set) var authorizationStatusDescription = "unknown"

    init() {
        refreshAuthorizationStatus()
    }

    func refreshAuthorizationStatus() {
        let status = AuthorizationCenter.shared.authorizationStatus
        authorizationStatusDescription = String(describing: status)
        logAuthSnapshot(hypothesisId: "H2", location: "FamilyControlsAuthService.refreshAuthorizationStatus", message: "status refreshed")

        switch status {
        case .approved, .approvedWithDataAccess:
            isAuthorizationDenied = false
            isAuthorized = true
        case .denied:
            isAuthorizationDenied = true
            isAuthorized = false
        case .notDetermined:
            isAuthorizationDenied = false
            isAuthorized = false
        @unknown default:
            isAuthorizationDenied = false
            isAuthorized = false
        }
    }

    var canBlockAppsDuringSession: Bool {
        isAuthorized
    }

    var missingPermissions: [ScreenTimePermissionGap] {
        isAuthorized ? [] : [.familyControlsNotApproved]
    }

    var needsPermissionPrompt: Bool {
        !isAuthorized
    }

    func permissionAlertTitle() -> String {
        "Screen Time required"
    }

    func permissionAlertMessage() -> String {
        if isAuthorizationDenied {
            return """
            Screen Time access for Kiddly is turned off.

            Open Settings → Screen Time → Apps with Screen Time Access, enable Kiddly, then return here.
            """
        }
        return """
            Kiddly needs Screen Time permission to run parent sessions:

            • Block apps during sessions based on your allowed-app choices
            • Show estimated app usage via Apple's Screen Time report

            Tap Continue for Apple's permission screen, then allow access.
            """
    }

    func sessionPermissionBlockedMessage() -> String? {
        guard !canBlockAppsDuringSession else { return nil }
        return permissionAlertMessage()
    }

    func recordingBlockedMessage() -> String? {
        sessionPermissionBlockedMessage()
    }

    func requestAuthorization() async throws {
        logAuthSnapshot(hypothesisId: "H1", location: "FamilyControlsAuthService.requestAuthorization", message: "calling AuthorizationCenter.requestAuthorization")
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        refreshAuthorizationStatus()
        logAuthSnapshot(hypothesisId: "H1", location: "FamilyControlsAuthService.requestAuthorization", message: "AuthorizationCenter returned")
        if !isAuthorized {
            try await Task.sleep(for: .milliseconds(350))
            refreshAuthorizationStatus()
            logAuthSnapshot(hypothesisId: "H2", location: "FamilyControlsAuthService.requestAuthorization", message: "status after 350ms retry")
        }
    }

    func ensureSessionAuthorization() async throws {
        refreshAuthorizationStatus()
        if isAuthorizationDenied {
            logAuthSnapshot(hypothesisId: "H2", location: "FamilyControlsAuthService.ensureSessionAuthorization", message: "blocked: denied")
            throw FamilyControlsAuthError.notAuthorized(status: authorizationStatusDescription)
        }
        if !isAuthorized {
            try await requestAuthorization()
            refreshAuthorizationStatus()
        }
        guard isAuthorized else {
            logAuthSnapshot(hypothesisId: "H2", location: "FamilyControlsAuthService.ensureSessionAuthorization", message: "blocked: still not authorized")
            throw FamilyControlsAuthError.notAuthorized(status: authorizationStatusDescription)
        }
        logAuthSnapshot(hypothesisId: "H4", location: "FamilyControlsAuthService.ensureSessionAuthorization", message: "session auth OK")
    }

    private func logAuthSnapshot(hypothesisId: String, location: String, message: String, runId: String = "pre-fix") {
        let profileFamilyControls = DebugSessionLog.embeddedProfileContains("family-controls")
        var data: [String: String] = [
            "buildChannel": DebugSessionLog.buildChannel.rawValue,
            "status": authorizationStatusDescription,
            "isAuthorized": String(isAuthorized),
            "needsPermissionPrompt": String(needsPermissionPrompt),
            "profileHasFamilyControls": profileFamilyControls.map { $0 ? "true" : "false" } ?? "unknown",
        ]
        DebugSessionLog.log(
            hypothesisId: hypothesisId,
            location: location,
            message: message,
            data: data,
            runId: runId
        )
    }
}

@Observable
@MainActor
final class PreviewFamilyControlsAuthService: FamilyControlsAuthProviding {
    var isAuthorized = true
    var canBlockAppsDuringSession = true
    var authorizationStatusDescription = "approved"
    var missingPermissions: [ScreenTimePermissionGap] = []
    var needsPermissionPrompt = false
    var isAuthorizationDenied = false

    func refreshAuthorizationStatus() {}

    func permissionAlertTitle() -> String { "Screen Time required" }

    func permissionAlertMessage() -> String { "Preview: permission granted." }

    func sessionPermissionBlockedMessage() -> String? { nil }

    func recordingBlockedMessage() -> String? { nil }

    func requestAuthorization() async throws {
        isAuthorized = true
        canBlockAppsDuringSession = true
        missingPermissions = []
        needsPermissionPrompt = false
    }

    func ensureSessionAuthorization() async throws {
        try await requestAuthorization()
    }
}
