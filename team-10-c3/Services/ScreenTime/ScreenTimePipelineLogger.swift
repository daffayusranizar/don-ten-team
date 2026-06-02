import Foundation
import os

/// Human-readable Screen Time pipeline logging (NDJSON + Xcode console in DEBUG).
enum ScreenTimePipelineLogger {
    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let consoleLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "team-10-c3", category: "ScreenTimePipeline")

    static func formatApps(_ apps: [AppUsageRow], maxRows: Int = 50) -> String {
        guard !apps.isEmpty else { return "(no apps)" }
        return apps
            .sorted { $0.durationSeconds > $1.durationSeconds }
            .prefix(maxRows)
            .map { row in
                "\(row.displayName) · \(row.bundleIdentifier) · \(row.durationSeconds)s"
            }
            .joined(separator: "\n")
    }

    static func logFilter(
        label: String,
        startAt: Date,
        stopAt: Date,
        segment: String,
        users: String,
        devices: String,
        applicationTokenCount: Int
    ) {
        let sessionSeconds = max(1, Int(stopAt.timeIntervalSince(startAt)))
        let body = """
        filter=\(label)
        segment=\(segment)
        window \(iso8601.string(from: startAt)) → \(iso8601.string(from: stopAt)) (\(sessionSeconds)s)
        users=\(users) devices=\(devices) appTokens=\(applicationTokenCount)
        """
        emit(
            location: "pipeline:filter",
            message: "DeviceActivityFilter built",
            data: [
                "filterLabel": label,
                "segment": segment,
                "startAt": iso8601.string(from: startAt),
                "stopAt": iso8601.string(from: stopAt),
                "sessionSeconds": String(sessionSeconds),
                "users": users,
                "devices": devices,
                "applicationTokenCount": String(applicationTokenCount),
                "detail": body,
            ],
            consoleTitle: "FILTER",
            consoleBody: body
        )
    }

    static func logFetchStart(filterLabel: String, policy: String) {
        let body = "activityData(filteredBy: hourly+session, using: \(policy))"
        emit(
            location: "pipeline:fetchStart",
            message: "activityData stream starting",
            data: [
                "filterLabel": filterLabel,
                "policy": policy,
                "detail": body,
            ],
            consoleTitle: "FETCH_START",
            consoleBody: body
        )
    }

    static func logFetchEnd(
        filterLabel: String,
        policy: String,
        segmentCount: Int,
        overlappingSegmentCount: Int,
        applicationCount: Int,
        uniqueApps: Int,
        noiseFilteredCount: Int,
        apps: [AppUsageRow]
    ) {
        let appSum = apps.map(\.durationSeconds).reduce(0, +)
        let body = """
        [\(filterLabel) / \(policy)] segments=\(segmentCount) overlap=\(overlappingSegmentCount) apiRows=\(applicationCount) noiseDropped=\(noiseFilteredCount) apps=\(uniqueApps) sum=\(appSum)s
        \(formatApps(apps))
        """
        emit(
            location: "pipeline:fetchEnd",
            message: "activityData stream finished",
            data: [
                "filterLabel": filterLabel,
                "policy": policy,
                "segmentCount": String(segmentCount),
                "overlappingSegmentCount": String(overlappingSegmentCount),
                "applicationCount": String(applicationCount),
                "noiseFilteredCount": String(noiseFilteredCount),
                "uniqueApps": String(uniqueApps),
                "appSumSeconds": String(appSum),
                "appsList": formatApps(apps),
                "detail": body,
            ],
            consoleTitle: "FETCH_END",
            consoleBody: body
        )
    }

    static func logInput(
        childId: UUID,
        startAt: Date,
        stopAt: Date,
        filterLabels: [String],
        wallClockSeconds: Int
    ) {
        let body = """
        window \(iso8601.string(from: startAt)) → \(iso8601.string(from: stopAt)) (\(wallClockSeconds)s wall)
        filters: \(filterLabels.joined(separator: ", "))
        """
        emit(
            location: "pipeline:input",
            message: "activityData fetch input",
            data: [
                "childId": childId.uuidString,
                "startAt": iso8601.string(from: startAt),
                "stopAt": iso8601.string(from: stopAt),
                "wallClockSeconds": String(wallClockSeconds),
                "filterLabels": filterLabels.joined(separator: ","),
                "detail": body,
            ],
            consoleTitle: "INPUT",
            consoleBody: body
        )
    }

    static func logRawAPIRow(
        bundleId: String,
        displayName: String,
        localized: String,
        rawSeconds: Int,
        segmentStart: Date,
        segmentEnd: Date,
        disposition: String,
        hourBucketStart: Date? = nil,
        normalizedStart: Date? = nil,
        normalizedEnd: Date? = nil,
        overlapCapSeconds: Int? = nil,
        sessionCapSeconds: Int? = nil,
        cappedSeconds: Int? = nil,
        aggregation: String? = nil
    ) {
        var parts = [
            disposition,
            displayName,
            "(\(bundleId))",
            "raw=\(rawSeconds)s",
        ]
        if let hourBucketStart {
            parts.append("hour=\(iso8601.string(from: hourBucketStart))")
        }
        if let normalizedStart, let normalizedEnd {
            parts.append(
                "norm=\(iso8601.string(from: normalizedStart))…\(iso8601.string(from: normalizedEnd))"
            )
        }
        if let overlapCapSeconds {
            parts.append("overlapCap=\(overlapCapSeconds)s")
        }
        if let sessionCapSeconds {
            parts.append("sessionCap=\(sessionCapSeconds)s")
        }
        if let cappedSeconds {
            parts.append("capped=\(cappedSeconds)s")
        }
        if let aggregation {
            parts.append("agg=\(aggregation)")
        }
        parts.append("seg=\(iso8601.string(from: segmentStart))…\(iso8601.string(from: segmentEnd))")
        let line = parts.joined(separator: " ")

        var data: [String: String] = [
            "bundleId": bundleId,
            "displayName": displayName,
            "localized": localized,
            "rawSeconds": String(rawSeconds),
            "segmentStart": iso8601.string(from: segmentStart),
            "segmentEnd": iso8601.string(from: segmentEnd),
            "disposition": disposition,
            "line": line,
        ]
        if let hourBucketStart {
            data["hourBucketStart"] = iso8601.string(from: hourBucketStart)
        }
        if let normalizedStart {
            data["normalizedStart"] = iso8601.string(from: normalizedStart)
        }
        if let normalizedEnd {
            data["normalizedEnd"] = iso8601.string(from: normalizedEnd)
        }
        if let overlapCapSeconds {
            data["overlapCapSeconds"] = String(overlapCapSeconds)
        }
        if let sessionCapSeconds {
            data["sessionCapSeconds"] = String(sessionCapSeconds)
        }
        if let cappedSeconds {
            data["cappedSeconds"] = String(cappedSeconds)
        }
        if let aggregation {
            data["aggregation"] = aggregation
        }

        emit(
            location: "pipeline:rawRow",
            message: "activityData application row",
            data: data,
            consoleTitle: "RAW",
            consoleBody: line
        )
    }

    static func logCandidate(
        filterLabel: String,
        policy: String,
        apps: [AppUsageRow]
    ) {
        let appSum = apps.map(\.durationSeconds).reduce(0, +)
        let appsList = formatApps(apps)
        let body = "[\(filterLabel) / \(policy)] \(apps.count) apps, sum=\(appSum)s\n\(appsList)"
        emit(
            location: "pipeline:candidate",
            message: "activityData candidate payload",
            data: [
                "filterLabel": filterLabel,
                "policy": policy,
                "appCount": String(apps.count),
                "appSumSeconds": String(appSum),
                "appsList": appsList,
            ],
            consoleTitle: "CANDIDATE",
            consoleBody: body
        )
    }

    static func logSelected(
        filterLabel: String,
        policy: String,
        score: Int,
        apps: [AppUsageRow]
    ) {
        let appSum = apps.map(\.durationSeconds).reduce(0, +)
        let appsList = formatApps(apps)
        let body = "SELECTED [\(filterLabel) / \(policy)] score=\(score) sum=\(appSum)s\n\(appsList)"
        emit(
            location: "pipeline:selected",
            message: "selected activityData payload",
            data: [
                "filterLabel": filterLabel,
                "policy": policy,
                "score": String(score),
                "appCount": String(apps.count),
                "appSumSeconds": String(appSum),
                "appsList": appsList,
            ],
            consoleTitle: "SELECTED",
            consoleBody: body
        )
    }

    static func logOutput(
        stage: String,
        apps: [AppUsageRow],
        sessionElapsedSeconds: Int? = nil,
        extra: [String: String] = [:]
    ) {
        let appSum = apps.map(\.durationSeconds).reduce(0, +)
        var data: [String: String] = [
            "stage": stage,
            "appCount": String(apps.count),
            "appSumSeconds": String(appSum),
            "appsList": formatApps(apps),
        ]
        if let sessionElapsedSeconds {
            data["sessionElapsedSeconds"] = String(sessionElapsedSeconds)
        }
        for (key, value) in extra { data[key] = value }

        var body = "OUTPUT [\(stage)] apps=\(apps.count) sum=\(appSum)s"
        if let sessionElapsedSeconds {
            body += " session=\(sessionElapsedSeconds)s"
        }
        body += "\n\(formatApps(apps))"

        emit(
            location: "pipeline:output",
            message: "pipeline output \(stage)",
            data: data,
            consoleTitle: "OUTPUT(\(stage))",
            consoleBody: body
        )
    }

    private static func emit(
        location: String,
        message: String,
        data: [String: String],
        consoleTitle: String,
        consoleBody: String
    ) {
        AgentDebugLog.log(
            hypothesisId: "C",
            location: location,
            message: message,
            data: data
        )
        consoleLog.info("[\(consoleTitle)] \(consoleBody, privacy: .public)")
        print("[ScreenTime:\(consoleTitle)]\n\(consoleBody)\n---")
    }
}
