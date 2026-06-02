import SwiftUI

extension EnvironmentValues {
    @Entry var sessionCoordinator: SessionCoordinator = SessionCoordinator(
        sessionRepository: InMemorySessionRepository(),
        screenTimeService: ScreenTimeService()
    )
}
