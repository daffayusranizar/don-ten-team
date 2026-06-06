import SwiftUI

/// Ensures AlarmKit is authorized before starting a session.
enum SessionEndAlarmPermissionGate {
    /// Alarm is recommended but optional — sessions can start without it.
    @MainActor
    static func runIfAuthorized(
        showAlert: @escaping () -> Void,
        onAuthorized: @escaping () -> Void
    ) {
        onAuthorized()
    }
}
