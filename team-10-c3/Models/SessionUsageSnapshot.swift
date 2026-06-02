import Foundation
import SwiftData

@Model
public final class SessionUsageSnapshot {
    public var id: UUID
    public var childId: UUID
    public var startAt: Date
    public var stopAt: Date
    public var fetchedAt: Date
    public var totalSeconds: Int
    public var appUsageJSON: String

    public init(
        id: UUID = UUID(),
        childId: UUID,
        startAt: Date,
        stopAt: Date,
        fetchedAt: Date = Date(),
        totalSeconds: Int,
        appUsageJSON: String
    ) {
        self.id = id
        self.childId = childId
        self.startAt = startAt
        self.stopAt = stopAt
        self.fetchedAt = fetchedAt
        self.totalSeconds = totalSeconds
        self.appUsageJSON = appUsageJSON
    }

    public var appUsageRows: [AppUsageRow] {
        guard let data = appUsageJSON.data(using: .utf8),
              let rows = try? JSONDecoder().decode([AppUsageRow].self, from: data) else {
            return []
        }
        return rows
    }
}
