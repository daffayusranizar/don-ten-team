import SwiftUI

extension EnvironmentValues {
    @Entry var sessionRepository: SessionRepository = InMemorySessionRepository()
}
