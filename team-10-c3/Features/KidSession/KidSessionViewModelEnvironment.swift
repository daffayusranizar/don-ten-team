import SwiftUI

extension EnvironmentValues {
    @Entry var kidSessionViewModel: KidSessionViewModel = KidSessionViewModel(
        sessionCoordinator: SessionCoordinator(
            sessionRepository: InMemorySessionRepository(),
            screenTimeService: ScreenTimeService(),
            familyControlsAuth: PreviewFamilyControlsAuthService()
        )
    )
}
