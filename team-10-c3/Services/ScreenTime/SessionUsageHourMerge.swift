import Foundation

/// Helpers for session-window overlap checks and per-day snapshot merge.
enum SessionUsageHourMerge {
    /// Whether an activity segment intersects `[sessionStart, sessionEnd)`.
    static func overlapsSession(
        segmentInterval: DateInterval,
        sessionStart: Date,
        sessionEnd: Date
    ) -> Bool {
        max(segmentInterval.start, sessionStart) < min(segmentInterval.end, sessionEnd)
    }

    /// Merge per-app rows across saved sessions: sum each snapshot's capped totals per bundle.
    static func mergeAppsHourAware(from snapshots: [SessionUsageSnapshot]) -> [AppUsageRow] {
        var byBundle: [String: (name: String, seconds: Int)] = [:]

        for snapshot in snapshots {
            for app in snapshot.appUsageRows {
                guard app.durationSeconds > 0 else { continue }
                let existing = byBundle[app.bundleIdentifier]?.seconds ?? 0
                byBundle[app.bundleIdentifier] = (
                    app.displayName,
                    existing + app.durationSeconds
                )
            }
        }

        return byBundle.map { bundleId, entry in
            AppUsageRow(
                displayName: entry.name,
                bundleIdentifier: bundleId,
                durationSeconds: entry.seconds
            )
        }
        .sorted { $0.durationSeconds > $1.durationSeconds }
    }
}
