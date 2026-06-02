import Foundation
import SwiftData

@MainActor
protocol ChildRepository {
    func save(_ child: Child) throws
    func fetchAll() throws -> [Child]
}

@MainActor
final class SwiftDataChildRepository: ChildRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func save(_ child: Child) throws {
        modelContext.insert(child)
        try modelContext.save()
    }

    func fetchAll() throws -> [Child] {
        let descriptor = FetchDescriptor<Child>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }
}

@MainActor
final class InMemoryChildRepository: ChildRepository {
    private(set) var children: [Child] = []

    func save(_ child: Child) throws {
        children.append(child)
    }

    func fetchAll() throws -> [Child] {
        children
    }
}
