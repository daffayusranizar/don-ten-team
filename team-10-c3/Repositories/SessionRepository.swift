import Foundation
import SwiftData

struct ActiveSessionInfo: Sendable, Equatable {
    let childId: UUID
    let startedAt: Date
    let startMarkerId: UUID
}

struct CompletedSessionInfo: Sendable, Equatable {
    let childId: UUID
    let startedAt: Date
    let stoppedAt: Date
    let snapshot: SessionUsageSnapshot?
}

struct DayActivitySummary: Sendable, Equatable {
    let day: Date
    let isToday: Bool
    let isYesterday: Bool
    let mergedApps: [AppUsageRow]
    let totalSeconds: Int

    var periodTitle: String {
        if isToday { return "Today's Session" }
        if isYesterday { return "Yesterday's Session" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: day))'s Session"
    }

    static func from(snapshots: [SessionUsageSnapshot], day: Date, isToday: Bool, isYesterday: Bool) -> DayActivitySummary {
        let mergedApps = mergeApps(from: snapshots)
        let totalSeconds = mergedApps.map(\.durationSeconds).reduce(0, +)
        return DayActivitySummary(
            day: day,
            isToday: isToday,
            isYesterday: isYesterday,
            mergedApps: mergedApps,
            totalSeconds: totalSeconds
        )
    }

    private static func mergeApps(from snapshots: [SessionUsageSnapshot]) -> [AppUsageRow] {
        var totals: [String: (name: String, seconds: Int)] = [:]
        for snapshot in snapshots {
            for app in snapshot.appUsageRows {
                let existing = totals[app.bundleIdentifier]?.seconds ?? 0
                totals[app.bundleIdentifier] = (app.displayName, existing + app.durationSeconds)
            }
        }
        return totals.map { bundleId, value in
            AppUsageRow(
                displayName: value.name,
                bundleIdentifier: bundleId,
                durationSeconds: value.seconds
            )
        }
        .sorted { $0.durationSeconds > $1.durationSeconds }
    }
}

@MainActor
protocol SessionRepository {
    func recordMarker(childId: UUID, type: SessionMarkerType, timestamp: Date) throws -> SessionMarker
    func activeSession(for childId: UUID) throws -> ActiveSessionInfo?
    func lastCompletedSession(for childId: UUID) throws -> CompletedSessionInfo?
    func saveUsageSnapshot(
        childId: UUID,
        startAt: Date,
        stopAt: Date,
        totalSeconds: Int,
        appUsageRows: [AppUsageRow]
    ) throws -> SessionUsageSnapshot
    func fetchSnapshots(for childId: UUID, month: String) throws -> [SessionUsageSnapshot]
    func availableMonths(for childId: UUID) throws -> [String]
    func dayActivitySummary(for childId: UUID, referenceDate: Date?) throws -> DayActivitySummary?
    func todayActivitySummary(for childId: UUID, referenceDate: Date?) throws -> DayActivitySummary?
}

@MainActor
final class SwiftDataSessionRepository: SessionRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func recordMarker(childId: UUID, type: SessionMarkerType, timestamp: Date) throws -> SessionMarker {
        let marker = SessionMarker(childId: childId, timestamp: timestamp, type: type)
        modelContext.insert(marker)
        try modelContext.save()
        return marker
    }

    func activeSession(for childId: UUID) throws -> ActiveSessionInfo? {
        let markers = try fetchMarkers(for: childId)
        guard let lastStart = markers.last(where: { $0.type == .start }) else { return nil }

        let hasStopAfterStart = markers.contains {
            $0.type == .stop && $0.timestamp > lastStart.timestamp
        }
        guard !hasStopAfterStart else { return nil }

        return ActiveSessionInfo(
            childId: childId,
            startedAt: lastStart.timestamp,
            startMarkerId: lastStart.id
        )
    }

    func lastCompletedSession(for childId: UUID) throws -> CompletedSessionInfo? {
        let markers = try fetchMarkers(for: childId)
        guard let lastStop = markers.last(where: { $0.type == .stop }) else { return nil }

        guard let matchingStart = markers
            .filter({ $0.type == .start && $0.timestamp < lastStop.timestamp })
            .max(by: { $0.timestamp < $1.timestamp }) else {
            return nil
        }

        let snapshot = try latestSnapshot(
            childId: childId,
            startAt: matchingStart.timestamp,
            stopAt: lastStop.timestamp
        )

        return CompletedSessionInfo(
            childId: childId,
            startedAt: matchingStart.timestamp,
            stoppedAt: lastStop.timestamp,
            snapshot: snapshot
        )
    }

    func saveUsageSnapshot(
        childId: UUID,
        startAt: Date,
        stopAt: Date,
        totalSeconds: Int,
        appUsageRows: [AppUsageRow]
    ) throws -> SessionUsageSnapshot {
        let jsonData = try JSONEncoder().encode(appUsageRows)
        let json = String(data: jsonData, encoding: .utf8) ?? "[]"
        let snapshot = SessionUsageSnapshot(
            childId: childId,
            startAt: startAt,
            stopAt: stopAt,
            totalSeconds: totalSeconds,
            appUsageJSON: json
        )
        modelContext.insert(snapshot)
        try modelContext.save()
        return snapshot
    }

    func fetchSnapshots(for childId: UUID, month: String) throws -> [SessionUsageSnapshot] {
        let all = try fetchAllSnapshots(for: childId)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return all.filter { formatter.string(from: $0.stopAt) == month }
    }

    func availableMonths(for childId: UUID) throws -> [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let months = try fetchAllSnapshots(for: childId).map { formatter.string(from: $0.stopAt) }
        return Array(Set(months)).sorted(by: >)
    }

    func dayActivitySummary(for childId: UUID, referenceDate: Date?) throws -> DayActivitySummary? {
        let all = try fetchAllSnapshots(for: childId)
        let reference = referenceDate ?? Date()
        guard !all.isEmpty else { return nil }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: reference)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let grouped = Dictionary(grouping: all) { calendar.startOfDay(for: $0.stopAt) }

        if let todaySnapshots = grouped[today], !todaySnapshots.isEmpty {
            return DayActivitySummary.from(
                snapshots: todaySnapshots,
                day: today,
                isToday: true,
                isYesterday: false
            )
        }

        if let yesterdaySnapshots = grouped[yesterday], !yesterdaySnapshots.isEmpty {
            return DayActivitySummary.from(
                snapshots: yesterdaySnapshots,
                day: yesterday,
                isToday: false,
                isYesterday: true
            )
        }

        guard let latestDay = grouped.keys.sorted(by: >).first,
              let snapshots = grouped[latestDay], !snapshots.isEmpty else {
            return nil
        }

        return DayActivitySummary.from(
            snapshots: snapshots,
            day: latestDay,
            isToday: false,
            isYesterday: false
        )
    }

    func todayActivitySummary(for childId: UUID, referenceDate: Date?) throws -> DayActivitySummary? {
        let all = try fetchAllSnapshots(for: childId)
        let reference = referenceDate ?? Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: reference)
        let todaySnapshots = all.filter { calendar.isDate($0.stopAt, inSameDayAs: today) }
        guard !todaySnapshots.isEmpty else { return nil }
        return DayActivitySummary.from(
            snapshots: todaySnapshots,
            day: today,
            isToday: true,
            isYesterday: false
        )
    }

    private func fetchMarkers(for childId: UUID) throws -> [SessionMarker] {
        let childIdValue = childId
        var descriptor = FetchDescriptor<SessionMarker>(
            predicate: #Predicate { $0.childId == childIdValue },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func fetchAllSnapshots(for childId: UUID) throws -> [SessionUsageSnapshot] {
        let childIdValue = childId
        var descriptor = FetchDescriptor<SessionUsageSnapshot>(
            predicate: #Predicate { $0.childId == childIdValue },
            sortBy: [SortDescriptor(\.stopAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func latestSnapshot(childId: UUID, startAt: Date, stopAt: Date) throws -> SessionUsageSnapshot? {
        let snapshots = try fetchAllSnapshots(for: childId)
        return snapshots.first {
            abs($0.startAt.timeIntervalSince(startAt)) < 1
                && abs($0.stopAt.timeIntervalSince(stopAt)) < 1
        }
    }
}

@MainActor
final class InMemorySessionRepository: SessionRepository {
    private var markers: [SessionMarker] = []
    private var snapshots: [SessionUsageSnapshot] = []

    func recordMarker(childId: UUID, type: SessionMarkerType, timestamp: Date) throws -> SessionMarker {
        let marker = SessionMarker(childId: childId, timestamp: timestamp, type: type)
        markers.append(marker)
        return marker
    }

    func activeSession(for childId: UUID) throws -> ActiveSessionInfo? {
        let childMarkers = markers.filter { $0.childId == childId }.sorted { $0.timestamp < $1.timestamp }
        guard let lastStart = childMarkers.last(where: { $0.type == .start }) else { return nil }
        let hasStop = childMarkers.contains { $0.type == .stop && $0.timestamp > lastStart.timestamp }
        guard !hasStop else { return nil }
        return ActiveSessionInfo(childId: childId, startedAt: lastStart.timestamp, startMarkerId: lastStart.id)
    }

    func lastCompletedSession(for childId: UUID) throws -> CompletedSessionInfo? {
        let childMarkers = markers.filter { $0.childId == childId }.sorted { $0.timestamp < $1.timestamp }
        guard let lastStop = childMarkers.last(where: { $0.type == .stop }) else { return nil }
        guard let matchingStart = childMarkers
            .filter({ $0.type == .start && $0.timestamp < lastStop.timestamp })
            .max(by: { $0.timestamp < $1.timestamp }) else {
            return nil
        }
        let snapshot = snapshots.first {
            $0.childId == childId
                && abs($0.startAt.timeIntervalSince(matchingStart.timestamp)) < 1
                && abs($0.stopAt.timeIntervalSince(lastStop.timestamp)) < 1
        }
        return CompletedSessionInfo(
            childId: childId,
            startedAt: matchingStart.timestamp,
            stoppedAt: lastStop.timestamp,
            snapshot: snapshot
        )
    }

    func saveUsageSnapshot(
        childId: UUID,
        startAt: Date,
        stopAt: Date,
        totalSeconds: Int,
        appUsageRows: [AppUsageRow]
    ) throws -> SessionUsageSnapshot {
        let jsonData = try JSONEncoder().encode(appUsageRows)
        let json = String(data: jsonData, encoding: .utf8) ?? "[]"
        let snapshot = SessionUsageSnapshot(
            childId: childId,
            startAt: startAt,
            stopAt: stopAt,
            totalSeconds: totalSeconds,
            appUsageJSON: json
        )
        snapshots.append(snapshot)
        return snapshot
    }

    func fetchSnapshots(for childId: UUID, month: String) throws -> [SessionUsageSnapshot] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return snapshots.filter {
            $0.childId == childId && formatter.string(from: $0.stopAt) == month
        }
    }

    func availableMonths(for childId: UUID) throws -> [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let months = snapshots.filter { $0.childId == childId }.map { formatter.string(from: $0.stopAt) }
        return Array(Set(months)).sorted(by: >)
    }

    func dayActivitySummary(for childId: UUID, referenceDate: Date?) throws -> DayActivitySummary? {
        let childSnapshots = snapshots.filter { $0.childId == childId }
        guard !childSnapshots.isEmpty else { return nil }

        let calendar = Calendar.current
        let reference = referenceDate ?? Date()
        let today = calendar.startOfDay(for: reference)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let grouped = Dictionary(grouping: childSnapshots) { calendar.startOfDay(for: $0.stopAt) }

        if let todaySnapshots = grouped[today], !todaySnapshots.isEmpty {
            return DayActivitySummary.from(
                snapshots: todaySnapshots,
                day: today,
                isToday: true,
                isYesterday: false
            )
        }

        if let yesterdaySnapshots = grouped[yesterday], !yesterdaySnapshots.isEmpty {
            return DayActivitySummary.from(
                snapshots: yesterdaySnapshots,
                day: yesterday,
                isToday: false,
                isYesterday: true
            )
        }

        guard let latestDay = grouped.keys.sorted(by: >).first,
              let latestSnapshots = grouped[latestDay], !latestSnapshots.isEmpty else {
            return nil
        }

        return DayActivitySummary.from(
            snapshots: latestSnapshots,
            day: latestDay,
            isToday: false,
            isYesterday: false
        )
    }

    func todayActivitySummary(for childId: UUID, referenceDate: Date?) throws -> DayActivitySummary? {
        let reference = referenceDate ?? Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: reference)
        let todaySnapshots = snapshots.filter {
            $0.childId == childId && calendar.isDate($0.stopAt, inSameDayAs: today)
        }
        guard !todaySnapshots.isEmpty else { return nil }
        return DayActivitySummary.from(
            snapshots: todaySnapshots,
            day: today,
            isToday: true,
            isYesterday: false
        )
    }
}
