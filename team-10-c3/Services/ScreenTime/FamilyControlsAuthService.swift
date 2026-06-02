import Foundation
import FamilyControls

@MainActor
protocol FamilyControlsAuthProviding {
    var isAuthorized: Bool { get }
    func requestAuthorization() async throws
}

@MainActor
final class FamilyControlsAuthService: FamilyControlsAuthProviding {
    private(set) var isAuthorized: Bool = false

    init() {
        refreshAuthorizationStatus()
    }

    func refreshAuthorizationStatus() {
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
    }

    func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        refreshAuthorizationStatus()
    }
}

@MainActor
final class PreviewFamilyControlsAuthService: FamilyControlsAuthProviding {
    var isAuthorized: Bool = true
    func requestAuthorization() async throws {}
}
