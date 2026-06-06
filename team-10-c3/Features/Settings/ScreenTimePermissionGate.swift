import SwiftUI

/// Checks Screen Time permission and presents the standard alert when missing.
enum ScreenTimePermissionGate {
    @MainActor
    static func runIfAuthorized(
        auth: FamilyControlsAuthProviding,
        showAlert: @escaping () -> Void,
        onAuthorized: @escaping () -> Void
    ) {
        auth.refreshAuthorizationStatus()
        guard auth.needsPermissionPrompt else {
            onAuthorized()
            return
        }
        if auth.isAuthorizationDenied {
            showAlert()
            return
        }
        Task {
            do {
                try await auth.ensureSessionAuthorization()
                onAuthorized()
            } catch {
                showAlert()
            }
        }
    }
}
