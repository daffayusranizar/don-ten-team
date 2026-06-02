import SwiftUI

extension EnvironmentValues {
    @Entry var childRepository: ChildRepository = InMemoryChildRepository()
}
