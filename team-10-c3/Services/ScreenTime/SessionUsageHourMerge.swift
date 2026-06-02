import Foundation

/// Hour-bucket helpers: query Apple hourly, aggregate per session hour, merge day snapshots.
enum SessionUsageHourMerge {
    /// Calendar hour starts touched by `[startAt, stopAt)`.
    static func hourStartsOverlapping(
        startAt: Date,
        stopAt: Date,
        calendar: Calendar = .current
    ) -> [Date] {
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

    /// Session window intersected with a calendar hour (for logging / segment checks).
    static func sessionOverlapInHour(
        sessionStart: Date,
        sessionEnd: Date,
        hourStart: Date,
        calendar: Calendar = .current
    ) -> DateInterval? {
        guard let hourInterval = calendar.dateInterval(of: .hour, for: hourStart) else { return nil }
        let overlapStart = max(sessionStart, hourInterval.start)
        let overlapEnd = min(sessionEnd, hourInterval.end)
        guard overlapEnd > overlapStart else { return nil }
        return DateInterval(start: overlapStart, end: overlapEnd)
    }

    /// Whether a segment belongs to this calendar hour and overlaps the session.
    static func segmentInSessionHour(
        segmentInterval: DateInterval,
        sessionStart: Date,
        sessionEnd: Date,
        hourStart: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard let hourInterval = calendar.dateInterval(of: .hour, for: hourStart) else { return false }
        let segmentHour = calendar.dateInterval(of: .hour, for: segmentInterval.start)?.start
        guard segmentHour == hourInterval.start else { return false }
        return max(segmentInterval.start, sessionStart) < min(segmentInterval.end, sessionEnd)
    }

    /// Whether a segment belongs to this calendar hour and overlaps any session window.
    static func segmentOverlapsAnySession(
        segmentInterval: DateInterval,
        sessions: [(startAt: Date, stopAt: Date)],
        hourStart: Date,
        calendar: Calendar = .current
    ) -> Bool {
        sessions.contains { session in
            segmentInSessionHour(
                segmentInterval: segmentInterval,
                sessionStart: session.startAt,
                sessionEnd: session.stopAt,
                hourStart: hourStart,
                calendar: calendar
            )
        }
    }

    /// Merged session-overlap intervals within one calendar hour.
    static func unionCoverageIntervalsInHour(
        sessions: [(startAt: Date, stopAt: Date)],
        hourStart: Date,
        calendar: Calendar = .current
    ) -> [DateInterval] {
        let overlaps = sessions.compactMap { session in
            sessionOverlapInHour(
                sessionStart: session.startAt,
                sessionEnd: session.stopAt,
                hourStart: hourStart,
                calendar: calendar
            )
        }
        guard !overlaps.isEmpty else { return [] }

        let sorted = overlaps.sorted { $0.start < $1.start }
        var merged: [DateInterval] = [sorted[0]]
        for interval in sorted.dropFirst() {
            var last = merged[merged.count - 1]
            if interval.start <= last.end {
                last = DateInterval(
                    start: last.start,
                    end: max(last.end, interval.end)
                )
                merged[merged.count - 1] = last
            } else {
                merged.append(interval)
            }
        }
        return merged
    }

    /// Wall-clock seconds parent sessions covered in a calendar hour (union of overlaps).
    static func coveredSecondsInHour(
        sessions: [(startAt: Date, stopAt: Date)],
        hourStart: Date,
        calendar: Calendar = .current
    ) -> Int {
        unionCoverageIntervalsInHour(
            sessions: sessions,
            hourStart: hourStart,
            calendar: calendar
        )
        .reduce(0) { total, interval in
            total + max(0, Int(interval.duration.rounded()))
        }
    }

    /// Local hour numbers (0–23) where sessions did not cover the full calendar hour.
    static func partialHourNumbers(
        sessions: [(startAt: Date, stopAt: Date)],
        calendar: Calendar = .current
    ) -> Set<Int> {
        var partial = Set<Int>()
        for hourStart in unionHourStarts(sessions: sessions, calendar: calendar) {
            guard let hourInterval = calendar.dateInterval(of: .hour, for: hourStart) else {
                continue
            }
            let expected = Int(hourInterval.duration.rounded())
            let covered = coveredSecondsInHour(
                sessions: sessions,
                hourStart: hourStart,
                calendar: calendar
            )
            if covered < expected - 1 {
                partial.insert(calendar.component(.hour, from: hourStart))
            }
        }
        return partial
    }

    /// Union of calendar hour starts touched by any session.
    static func unionHourStarts(
        sessions: [(startAt: Date, stopAt: Date)],
        calendar: Calendar = .current
    ) -> [Date] {
        var seen = Set<TimeInterval>()
        var hours: [Date] = []
        for session in sessions {
            for hourStart in hourStartsOverlapping(
                startAt: session.startAt,
                stopAt: session.stopAt,
                calendar: calendar
            ) {
                let key = hourStart.timeIntervalSince1970
                if seen.insert(key).inserted {
                    hours.append(hourStart)
                }
            }
        }
        return hours.sorted()
    }

    /// Sum per-app seconds across hourly rows (for app list totals).
    static func mergedApps(from hourlyRows: [HourlyAppUsageRow]) -> [AppUsageRow] {
        var byBundle: [String: (name: String, seconds: Int)] = [:]
        for row in hourlyRows where row.durationSeconds > 0 {
            let existing = byBundle[row.bundleIdentifier]?.seconds ?? 0
            byBundle[row.bundleIdentifier] = (row.displayName, existing + row.durationSeconds)
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

    /// Max raw seconds in the same hour bucket (dedupe duplicate hourly rows from Apple).
    static func maxInHourBucket(existing: Int, added: Int) -> Int {
        max(existing, added)
    }

}
