import Foundation
import SwiftData

@Model
public final class SessionUsageSnapshot {
    public var id: UUID
    public var childId: UUID
    public var startAt: Date
    public var stopAt: Date
    public var fetchedAt: Date
    /// Wall-clock active session time (matches parent timer).
    public var totalSeconds: Int
    /// Legacy field; app usage is fetched live for charts, not persisted.
    public var screenTimeAppTotalSeconds: Int
    /// Parent-chosen session limit at start (e.g. 30 min). 0 on legacy snapshots.
    public var plannedDurationSeconds: Int
    /// Legacy JSON; timer-only saves use `[]`.
    public var appUsageJSON: String

    public init(
        id: UUID = UUID(),
        childId: UUID,
        startAt: Date,
        stopAt: Date,
        fetchedAt: Date = Date(),
        totalSeconds: Int,
        screenTimeAppTotalSeconds: Int = 0,
        plannedDurationSeconds: Int = 0,
        appUsageJSON: String = "[]"
    ) {
        self.id = id
        self.childId = childId
        self.startAt = startAt
        self.stopAt = stopAt
        self.fetchedAt = fetchedAt
        self.totalSeconds = totalSeconds
        self.screenTimeAppTotalSeconds = screenTimeAppTotalSeconds
        self.plannedDurationSeconds = plannedDurationSeconds
        self.appUsageJSON = appUsageJSON
    }

    public var resolvedScreenTimeSeconds: Int {
        if screenTimeAppTotalSeconds > 0 { return screenTimeAppTotalSeconds }
        return appUsageRows.map(\.durationSeconds).reduce(0, +)
    }

    public var appUsageRows: [AppUsageRow] {
        guard let data = appUsageJSON.data(using: .utf8),
              let rows = try? JSONDecoder().decode([AppUsageRow].self, from: data) else {
            return []
        }
        if SessionUsageSanitizer.isLegacyMockAppList(rows) { return [] }
        return rows
    }
}
