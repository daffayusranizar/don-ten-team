import DeviceActivity
import Foundation

/// Picks the best single `activityData` candidate (avoids max-merge inflation across filter attempts).
enum ScreenTimePayloadSelector {
    struct Candidate: Sendable {
        let payload: SessionUsagePayload
        let score: Int
        let filterLabel: String
        let policy: String
    }

    #if DEBUG
    private(set) static var lastUniformDurationRejected = false
    #endif

    static func selectBest(
        from candidates: [(payload: SessionUsagePayload, filterLabel: String, policy: String)],
        wallClockSeconds: Int
    ) -> Candidate? {
        #if DEBUG
        lastUniformDurationRejected = false
        #endif
        let scored = candidates.compactMap { item -> Candidate? in
            guard let score = score(
                payload: item.payload,
                wallClockSeconds: wallClockSeconds,
                filterLabel: item.filterLabel,
                policy: item.policy
            ) else { return nil }
            return Candidate(
                payload: item.payload,
                score: score,
                filterLabel: item.filterLabel,
                policy: item.policy
            )
        }
        return scored.max(by: { $0.score < $1.score })
    }

    /// Prefer the richer of two successive fetches (backfill), not max per app across filters.
    static func preferRicher(
        existing: SessionUsagePayload?,
        new: SessionUsagePayload,
        wallClockSeconds: Int
    ) -> SessionUsagePayload {
        guard let existing else { return new }
        let existingScore = score(
            payload: existing,
            wallClockSeconds: wallClockSeconds,
            filterLabel: "existing",
            policy: "existing"
        ) ?? Int.min
        let newScore = score(
            payload: new,
            wallClockSeconds: wallClockSeconds,
            filterLabel: "new",
            policy: "new"
        ) ?? Int.min
        return newScore > existingScore ? new : existing
    }

    static func qualityScore(payload: SessionUsagePayload, wallClockSeconds: Int) -> Int {
        score(
            payload: payload,
            wallClockSeconds: wallClockSeconds,
            filterLabel: "retry",
            policy: "retry"
        ) ?? Int.min
    }

    private static func score(
        payload: SessionUsagePayload,
        wallClockSeconds: Int,
        filterLabel: String,
        policy: String
    ) -> Int? {
        let apps = payload.apps.filter { isValidBundle($0.bundleIdentifier) }
        guard !apps.isEmpty else { return nil }

        let appSum = apps.map(\.durationSeconds).reduce(0, +)
        let wall = max(1, wallClockSeconds)

        if apps.count > 3, apps.allSatisfy({ $0.durationSeconds <= 1 }) {
            return nil
        }

        if hasUniformDurationPattern(apps: apps) {
            #if DEBUG
            lastUniformDurationRejected = true
            AgentDebugLog.log(
                hypothesisId: "C",
                location: "ScreenTimePayloadSelector.score",
                message: "rejected uniform-duration payload",
                data: [
                    "appCount": String(apps.count),
                    "sharedSeconds": String(apps.first?.durationSeconds ?? 0),
                    "filterLabel": filterLabel,
                    "policy": policy,
                ]
            )
            #endif
            return nil
        }

        var points = 0
        points += min(apps.count, 20) * 50
        points += min(appSum, 3600)

        let validBundleCount = apps.filter { $0.bundleIdentifier.contains(".") }.count
        points += validBundleCount * 30

        if filterLabel.contains("hourly") { points += 40 }

        if policy.contains("live") { points += 25 }

        if appSum > wall * 3 { points -= 200 }
        else if appSum > wall { points -= Int((appSum - wall) / 10) }
        else {
            let gap = wall - appSum
            points -= min(gap / 30, 80)
        }

        return points
    }

    private static func isValidBundle(_ bundleId: String) -> Bool {
        bundleId.contains(".")
    }

    /// Many apps with identical seconds often indicates cap/noise artifacts, not real usage.
    private static func hasUniformDurationPattern(apps: [AppUsageRow]) -> Bool {
        let positive = apps.filter { $0.durationSeconds > 0 }
        guard positive.count >= 4 else { return false }
        return Set(positive.map(\.durationSeconds)).count == 1
    }
}
