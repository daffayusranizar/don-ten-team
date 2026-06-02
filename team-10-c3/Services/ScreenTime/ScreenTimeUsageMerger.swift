import Foundation

enum ScreenTimeUsageMerger {
    /// Combines multiple filter/policy attempts; per-app seconds use the maximum (never sum duplicate reads).
    static func merge(
        childId: UUID,
        startAt: Date,
        stopAt: Date,
        payloads: [SessionUsagePayload]
    ) -> SessionUsagePayload {
        var totals: [String: (name: String, seconds: Int)] = [:]

        for payload in payloads {
            for app in payload.apps {
                guard app.durationSeconds > 0 else { continue }
                let bundleKey = normalizedBundleKey(app.bundleIdentifier)
                let existing = totals[bundleKey]?.seconds ?? 0
                let seconds = max(existing, app.durationSeconds)
                let name = preferredName(
                    existing: totals[bundleKey]?.name,
                    candidate: app.displayName,
                    bundleId: bundleKey
                )
                totals[bundleKey] = (name, seconds)
            }
        }

        let apps = totals.map { bundleId, value in
            AppUsageRow(
                displayName: value.name,
                bundleIdentifier: bundleId,
                durationSeconds: value.seconds
            )
        }
        .sorted { $0.durationSeconds > $1.durationSeconds }

        let totalSeconds = apps.map(\.durationSeconds).reduce(0, +)
        return SessionUsagePayload(
            childId: childId,
            startAt: startAt,
            stopAt: stopAt,
            totalSeconds: totalSeconds,
            apps: apps
        )
    }

    private static func normalizedBundleKey(_ bundleId: String) -> String {
        bundleId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func preferredName(existing: String?, candidate: String, bundleId: String) -> String {
        let fromBundle = KnownAppLabels.displayName(bundleId: bundleId, localized: nil)
        if fromBundle != AppDisplayNameFormatter.fromBundleIdentifier(bundleId) {
            return fromBundle
        }
        if let existing, !existing.isEmpty, existing != "Unknown app" {
            return existing
        }
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "App" || trimmed == "Unknown app" {
            return fromBundle
        }
        return trimmed
    }
}
