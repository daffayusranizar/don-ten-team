import SwiftUI

extension EnvironmentValues {
    @Entry var profileViewModel: ProfileViewModel = ProfileViewModel(
        childRepository: InMemoryChildRepository()
    )
}
