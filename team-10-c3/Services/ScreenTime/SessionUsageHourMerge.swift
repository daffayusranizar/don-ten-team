import Foundation

/// Hour-bucket helpers for hybrid overlap aggregation and per-day snapshot merge.
enum SessionUsageHourMerge {
    /// Calendar hour starts touched by `[startAt, stopAt)`.
    static func hourStartsOverlapping(startAt: Date, stopAt: Date, calendar: Calendar = .current) -> [Date] {
        guard stopAt > startAt else { return [] }
        var hours: [Date] = []
        var cursor = calendar.dateInterval(of: .hour, for: startAt)?.start ?? startAt
        let end = stopAt
        while cursor < end {
            hours.append(cursor)
            guard let next = calendar.date(byAdding: .hour, value: 1, to: cursor) else { break }
            cursor = next
        }
        return hours
    }

    /// Seconds of `[sessionStart, sessionEnd)` inside the calendar hour starting at `hourStart`.
    static func overlapSecondsInHour(
        hourStart: Date,
        sessionStart: Date,
        sessionEnd: Date,
        calendar: Calendar = .current
    ) -> Int {
        guard sessionEnd > sessionStart else { return 0 }
        guard let hourInterval = calendar.dateInterval(of: .hour, for: hourStart) else { return 0 }
        let overlapStart = max(sessionStart, hourInterval.start)
        let overlapEnd = min(sessionEnd, hourInterval.end)
        guard overlapEnd > overlapStart else { return 0 }
        return max(1, Int(overlapEnd.timeIntervalSince(overlapStart).rounded()))
    }

    /// Overlap of session window with segment, clipped to the calendar hour containing that overlap.
    static func normalizedHourOverlap(
        segmentInterval: DateInterval,
        sessionStart: Date,
        sessionEnd: Date,
        calendar: Calendar = .current
    ) -> (hourStart: Date, normalizedStart: Date, normalizedEnd: Date, overlapInHour: TimeInterval)? {
        let overlapStart = max(segmentInterval.start, sessionStart)
        let overlapEnd = min(segmentInterval.end, sessionEnd)
        guard overlapEnd > overlapStart else { return nil }
        guard let hourInterval = calendar.dateInterval(of: .hour, for: overlapStart) else { return nil }

        let normalizedStart = max(overlapStart, hourInterval.start)
        let normalizedEnd = min(overlapEnd, hourInterval.end)
        guard normalizedEnd > normalizedStart else { return nil }

        return (
            hourInterval.start,
            normalizedStart,
            normalizedEnd,
            normalizedEnd.timeIntervalSince(normalizedStart)
        )
    }

    /// Per API row: cannot exceed Apple raw, session overlap in this hour, or full session wall clock.
    static func cappedSeconds(
        rawSeconds: Int,
        overlapInHour: TimeInterval,
        sessionWallClockSeconds: Int
    ) -> Int {
        guard rawSeconds > 0, overlapInHour > 0, sessionWallClockSeconds > 0 else { return 0 }
        let overlapCap = max(1, Int(overlapInHour.rounded()))
        return min(rawSeconds, overlapCap, sessionWallClockSeconds)
    }

    /// Sum capped rows in the same hour, then cap at that hour's session overlap.
    static func accumulateInHourBucket(existing: Int, added: Int, hourOverlapSeconds: Int) -> Int {
        guard added > 0 else { return existing }
        let sum = existing + added
        guard hourOverlapSeconds > 0 else { return sum }
        return min(sum, max(1, hourOverlapSeconds))
    }

    /// After summing distinct hour buckets, a single app cannot exceed session length.
    static func cappedBundleTotal(sumAcrossHours: Int, sessionWallClockSeconds: Int) -> Int {
        guard sumAcrossHours > 0, sessionWallClockSeconds > 0 else { return 0 }
        return min(sumAcrossHours, sessionWallClockSeconds)
    }

    /// Merge per-app rows across sessions: sum per (bundle, hour) with hour cap, then sum hours per bundle.
    static func mergeAppsHourAware(from snapshots: [SessionUsageSnapshot]) -> [AppUsageRow] {
        var byBundleHour: [String: [Date: (name: String, seconds: Int)]] = [:]

        for snapshot in snapshots {
            let hours = hourStartsOverlapping(startAt: snapshot.startAt, stopAt: snapshot.stopAt)
            guard !hours.isEmpty else { continue }

            for app in snapshot.appUsageRows {
                guard app.durationSeconds > 0 else { continue }
                var hourMap = byBundleHour[app.bundleIdentifier] ?? [:]
                for hourStart in hours {
                    let hourOverlapSec = overlapSecondsInHour(
                        hourStart: hourStart,
                        sessionStart: snapshot.startAt,
                        sessionEnd: snapshot.stopAt
                    )
                    let existing = hourMap[hourStart]?.seconds ?? 0
                    let hourly = accumulateInHourBucket(
                        existing: existing,
                        added: app.durationSeconds,
                        hourOverlapSeconds: hourOverlapSec
                    )
                    hourMap[hourStart] = (app.displayName, hourly)
                }
                byBundleHour[app.bundleIdentifier] = hourMap
            }
        }

        return byBundleHour.map { bundleId, hourMap in
            let name = hourMap.values.first?.name ?? bundleId
            let seconds = hourMap.values.map(\.seconds).reduce(0, +)
            return AppUsageRow(
                displayName: name,
                bundleIdentifier: bundleId,
                durationSeconds: seconds
            )
        }
        .sorted { $0.durationSeconds > $1.durationSeconds }
    }
}
