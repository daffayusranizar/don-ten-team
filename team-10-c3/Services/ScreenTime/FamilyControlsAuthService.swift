import Foundation
import FamilyControls
import Observation

@MainActor
protocol FamilyControlsAuthProviding: AnyObject {
    var isAuthorized: Bool { get }
    var hasUsageDataAccess: Bool { get }
    /// Per-app session usage can be recorded only when this is true.
    var canRecordSessionUsage: Bool { get }
    var authorizationStatusDescription: String { get }
    func refreshAuthorizationStatus()
    func requestAuthorization() async throws
    /// Shows the system Screen Time permission sheet if usage data access is not granted yet.
    func ensureUsageAuthorization() async throws
    /// User-facing reason when `canRecordSessionUsage` is false; nil when recording is allowed.
    func recordingBlockedMessage() -> String?
}

enum FamilyControlsAuthError: LocalizedError {
    case usageAccessNotGranted(status: String)

    var errorDescription: String? {
        switch self {
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

    var canRecordSessionUsage: Bool {
        hasUsageDataAccess
    }

    func recordingBlockedMessage() -> String? {
        guard !canRecordSessionUsage else { return nil }
        if !isAuthorized {
            return "Screen Time access is required before starting a session. Tap Enable to allow access, then try again."
        }
        return ScreenTimeFetchError.missingUsageDataAccess(
            status: authorizationStatusDescription
        ).localizedDescription
    }

    func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        refreshAuthorizationStatus()
    }

    func ensureUsageAuthorization() async throws {
        refreshAuthorizationStatus()
        if canRecordSessionUsage { return }

        try await requestAuthorization()
        refreshAuthorizationStatus()

        guard canRecordSessionUsage else {
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
    var canRecordSessionUsage = true
    var authorizationStatusDescription = "approvedWithDataAccess"

    func refreshAuthorizationStatus() {}

    func recordingBlockedMessage() -> String? { nil }

    func requestAuthorization() async throws {
        isAuthorized = true
        hasUsageDataAccess = true
        canRecordSessionUsage = true
    }

    func ensureUsageAuthorization() async throws {
        try await requestAuthorization()
    }
}
