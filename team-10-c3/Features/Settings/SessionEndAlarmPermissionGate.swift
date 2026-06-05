import SwiftUI

/// Ensures AlarmKit is authorized before starting a session.
enum SessionEndAlarmPermissionGate {
    @MainActor
    static func runIfAuthorized(
        showAlert: @escaping () -> Void,
        onAuthorized: @escaping () -> Void
    ) {
        guard SessionEndAlarmScheduler.isAuthorized else {
            showAlert()
            return
        }
        onAuthorized()
    }
}
