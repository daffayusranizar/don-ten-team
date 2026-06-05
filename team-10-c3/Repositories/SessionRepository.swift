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

struct SessionWindow: Sendable, Equatable {
    let startAt: Date
    let stopAt: Date
}

struct CompletedSessionReference: Sendable, Equatable {
    let sessionId: UUID
    let startAt: Date
    let stopAt: Date
}

struct DayActivitySummary: Sendable, Equatable {
    let day: Date
    let isToday: Bool
    let isYesterday: Bool
    let sessionCount: Int
    /// Sum of wall-clock session timers that day (parent-facing headline).
    let totalSeconds: Int

    var periodTitle: String {
        let base: String
        if isToday {
            base = "Today"
        } else if isYesterday {
            base = "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            base = formatter.string(from: day)
        }
        if sessionCount > 1 {
            return "\(base) (\(sessionCount) sessions)"
        }
        return base
    }

    static func from(snapshots: [SessionUsageSnapshot], day: Date, isToday: Bool, isYesterday: Bool) -> DayActivitySummary {
        let sessionElapsed = snapshots.map(\.totalSeconds).reduce(0, +)
        return DayActivitySummary(
            day: day,
            isToday: isToday,
            isYesterday: isYesterday,
            sessionCount: snapshots.count,
            totalSeconds: sessionElapsed
        )
    }
}

private enum SessionMarkerPairing {
    /// Latest unpaired `.start` per child (no later `.stop` for that start).
    static func unpairedActiveSessions(markers: [SessionMarker]) -> [ActiveSessionInfo] {
        let byChild = Dictionary(grouping: markers) { $0.childId }
        var actives: [ActiveSessionInfo] = []

        for (childId, childMarkers) in byChild {
            let sorted = childMarkers.sorted { $0.timestamp < $1.timestamp }
            guard let lastStart = sorted.last(where: { $0.type == .start }) else { continue }
            let hasStopAfterStart = sorted.contains {
                $0.type == .stop && $0.timestamp > lastStart.timestamp
            }
            guard !hasStopAfterStart else { continue }
            actives.append(
                ActiveSessionInfo(
                    childId: childId,
                    startedAt: lastStart.timestamp,
                    startMarkerId: lastStart.id
                )
            )
        }
        return actives
    }

    static func completedWindows(
        markers: [SessionMarker],
        childId: UUID,
        day: Date,
        calendar: Calendar = .current
    ) -> [SessionWindow] {
        completedSessions(
            markers: markers,
            childId: childId,
            day: day,
            calendar: calendar
        ).map { SessionWindow(startAt: $0.startAt, stopAt: $0.stopAt) }
    }

    static func completedSessions(
        markers: [SessionMarker],
        childId: UUID,
        day: Date,
        calendar: Calendar = .current
    ) -> [CompletedSessionReference] {
        let childMarkers = markers
            .filter { $0.childId == childId }
            .sorted { $0.timestamp < $1.timestamp }

        var sessions: [CompletedSessionReference] = []
        var pendingStart: (id: UUID, timestamp: Date)?

        for marker in childMarkers {
            switch marker.type {
            case .start:
                pendingStart = (marker.id, marker.timestamp)
            case .stop:
                guard let start = pendingStart, start.timestamp < marker.timestamp else {
                    pendingStart = nil
                    continue
                }
                if calendar.isDate(marker.timestamp, inSameDayAs: day) {
                    sessions.append(
                        CompletedSessionReference(
                            sessionId: start.id,
                            startAt: start.timestamp,
                            stopAt: marker.timestamp
                        )
                    )
                }
                pendingStart = nil
            }
        }
        return sessions
    }
}

private enum SessionSnapshotMatching {
    static let windowTolerance: TimeInterval = 5

    static func matches(
        snapshot: SessionUsageSnapshot,
        childId: UUID,
        startAt: Date,
        stopAt: Date
    ) -> Bool {
        snapshot.childId == childId
            && abs(snapshot.startAt.timeIntervalSince(startAt)) < windowTolerance
            && abs(snapshot.stopAt.timeIntervalSince(stopAt)) < windowTolerance
    }

    static func preferRicher(_ lhs: SessionUsageSnapshot, _ rhs: SessionUsageSnapshot) -> SessionUsageSnapshot {
        lhs.fetchedAt >= rhs.fetchedAt ? lhs : rhs
    }
}

@MainActor
protocol SessionRepository {
    func recordMarker(
        childId: UUID,
        type: SessionMarkerType,
        timestamp: Date,
        id: UUID
    ) throws -> SessionMarker
    /// Unpaired start markers across all children; keeps the newest and stops older orphans.
    func resolveGlobalActiveSession() throws -> ActiveSessionInfo?
    func activeSession(for childId: UUID) throws -> ActiveSessionInfo?
    func lastCompletedSession(for childId: UUID) throws -> CompletedSessionInfo?
    func saveUsageSnapshot(
        childId: UUID,
        startAt: Date,
        stopAt: Date,
        totalSeconds: Int,
        plannedDurationSeconds: Int
    ) throws -> SessionUsageSnapshot
    func updateSnapshotScreenTimeTotals(
        _ snapshot: SessionUsageSnapshot,
        screenTimeAppTotalSeconds: Int
    ) throws
    func completedSessionWindows(for childId: UUID, day: Date) throws -> [SessionWindow]
    func completedSessions(for childId: UUID, day: Date) throws -> [CompletedSessionReference]
    func snapshots(for childId: UUID, on day: Date) throws -> [SessionUsageSnapshot]
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

    func recordMarker(
        childId: UUID,
        type: SessionMarkerType,
        timestamp: Date,
        id: UUID = UUID()
    ) throws -> SessionMarker {
        let marker = SessionMarker(id: id, childId: childId, timestamp: timestamp, type: type)
        modelContext.insert(marker)
        try modelContext.save()
        return marker
    }

    func resolveGlobalActiveSession() throws -> ActiveSessionInfo? {
        let markers = try fetchAllMarkers()
        let actives = SessionMarkerPairing.unpairedActiveSessions(markers: markers)
        guard let primary = actives.max(by: { $0.startedAt < $1.startedAt }) else { return nil }

        let stopAt = Date()
        for orphan in actives where orphan.startMarkerId != primary.startMarkerId {
            _ = try recordMarker(
                childId: orphan.childId,
                type: .stop,
                timestamp: stopAt,
                id: UUID()
            )
        }
        return primary
    }

    func activeSession(for childId: UUID) throws -> ActiveSessionInfo? {
        let markers = try fetchMarkers(for: childId)
        return SessionMarkerPairing.unpairedActiveSessions(markers: markers).first
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

    func completedSessionWindows(for childId: UUID, day: Date) throws -> [SessionWindow] {
        let markers = try fetchMarkers(for: childId)
        return SessionMarkerPairing.completedWindows(
            markers: markers,
            childId: childId,
            day: day
        )
    }

    func completedSessions(for childId: UUID, day: Date) throws -> [CompletedSessionReference] {
        let markers = try fetchMarkers(for: childId)
        return SessionMarkerPairing.completedSessions(
            markers: markers,
            childId: childId,
            day: day
        )
    }

    func saveUsageSnapshot(
        childId: UUID,
        startAt: Date,
        stopAt: Date,
        totalSeconds: Int,
        plannedDurationSeconds: Int
    ) throws -> SessionUsageSnapshot {
        let matching = try fetchAllSnapshots(for: childId).filter {
            SessionSnapshotMatching.matches(snapshot: $0, childId: childId, startAt: startAt, stopAt: stopAt)
        }

        if let existing = matching.reduce(nil as SessionUsageSnapshot?, { best, candidate in
            guard let best else { return candidate }
            return SessionSnapshotMatching.preferRicher(best, candidate)
        }) {
            existing.fetchedAt = Date()
            existing.totalSeconds = totalSeconds
            if plannedDurationSeconds > 0 {
                existing.plannedDurationSeconds = plannedDurationSeconds
            }
            for duplicate in matching where duplicate.id != existing.id {
                modelContext.delete(duplicate)
            }
            try modelContext.save()
            return existing
        }

        let snapshot = SessionUsageSnapshot(
            childId: childId,
            startAt: startAt,
            stopAt: stopAt,
            totalSeconds: totalSeconds,
            plannedDurationSeconds: plannedDurationSeconds
        )
        modelContext.insert(snapshot)
        try modelContext.save()
        return snapshot
    }

    func updateSnapshotScreenTimeTotals(
        _ snapshot: SessionUsageSnapshot,
        screenTimeAppTotalSeconds: Int
    ) throws {
        snapshot.screenTimeAppTotalSeconds = max(0, screenTimeAppTotalSeconds)
        snapshot.fetchedAt = Date()
        try modelContext.save()
    }

    func snapshots(for childId: UUID, on day: Date) throws -> [SessionUsageSnapshot] {
        let calendar = Calendar.current
        return try fetchAllSnapshots(for: childId).filter {
            calendar.isDate($0.stopAt, inSameDayAs: day)
        }
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

    private func fetchAllMarkers() throws -> [SessionMarker] {
        var descriptor = FetchDescriptor<SessionMarker>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
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
        let matching = try fetchAllSnapshots(for: childId).filter {
            SessionSnapshotMatching.matches(snapshot: $0, childId: childId, startAt: startAt, stopAt: stopAt)
        }
        return matching.reduce(nil) { best, candidate in
            guard let best else { return candidate }
            return SessionSnapshotMatching.preferRicher(best, candidate)
        }
    }
}

@MainActor
final class InMemorySessionRepository: SessionRepository {
    private var markers: [SessionMarker] = []
    private var snapshots: [SessionUsageSnapshot] = []

    func recordMarker(
        childId: UUID,
        type: SessionMarkerType,
        timestamp: Date,
        id: UUID = UUID()
    ) throws -> SessionMarker {
        let marker = SessionMarker(id: id, childId: childId, timestamp: timestamp, type: type)
        markers.append(marker)
        return marker
    }

    func resolveGlobalActiveSession() throws -> ActiveSessionInfo? {
        let actives = SessionMarkerPairing.unpairedActiveSessions(markers: markers)
        guard let primary = actives.max(by: { $0.startedAt < $1.startedAt }) else { return nil }

        let stopAt = Date()
        for orphan in actives where orphan.startMarkerId != primary.startMarkerId {
            _ = try recordMarker(
                childId: orphan.childId,
                type: .stop,
                timestamp: stopAt,
                id: UUID()
            )
        }
        return primary
    }

    func activeSession(for childId: UUID) throws -> ActiveSessionInfo? {
        let childMarkers = markers.filter { $0.childId == childId }
        return SessionMarkerPairing.unpairedActiveSessions(markers: childMarkers).first
    }

    func lastCompletedSession(for childId: UUID) throws -> CompletedSessionInfo? {
        let childMarkers = markers.filter { $0.childId == childId }.sorted { $0.timestamp < $1.timestamp }
        guard let lastStop = childMarkers.last(where: { $0.type == .stop }) else { return nil }
        guard let matchingStart = childMarkers
            .filter({ $0.type == .start && $0.timestamp < lastStop.timestamp })
            .max(by: { $0.timestamp < $1.timestamp }) else {
            return nil
        }
        let snapshot = snapshots
            .filter {
                SessionSnapshotMatching.matches(
                    snapshot: $0,
                    childId: childId,
                    startAt: matchingStart.timestamp,
                    stopAt: lastStop.timestamp
                )
            }
            .reduce(nil as SessionUsageSnapshot?) { best, candidate in
                guard let best else { return candidate }
                return SessionSnapshotMatching.preferRicher(best, candidate)
            }
        return CompletedSessionInfo(
            childId: childId,
            startedAt: matchingStart.timestamp,
            stoppedAt: lastStop.timestamp,
            snapshot: snapshot
        )
    }

    func completedSessionWindows(for childId: UUID, day: Date) throws -> [SessionWindow] {
        SessionMarkerPairing.completedWindows(
            markers: markers,
            childId: childId,
            day: day
        )
    }

    func completedSessions(for childId: UUID, day: Date) throws -> [CompletedSessionReference] {
        SessionMarkerPairing.completedSessions(
            markers: markers,
            childId: childId,
            day: day
        )
    }

    func saveUsageSnapshot(
        childId: UUID,
        startAt: Date,
        stopAt: Date,
        totalSeconds: Int,
        plannedDurationSeconds: Int
    ) throws -> SessionUsageSnapshot {
        let matching = snapshots.filter {
            SessionSnapshotMatching.matches(snapshot: $0, childId: childId, startAt: startAt, stopAt: stopAt)
        }

        if let existing = matching.reduce(nil as SessionUsageSnapshot?, { best, candidate in
            guard let best else { return candidate }
            return SessionSnapshotMatching.preferRicher(best, candidate)
        }) {
            existing.fetchedAt = Date()
            existing.totalSeconds = totalSeconds
            if plannedDurationSeconds > 0 {
                existing.plannedDurationSeconds = plannedDurationSeconds
            }
            snapshots.removeAll { snap in
                matching.contains(where: { $0.id == snap.id }) && snap.id != existing.id
            }
            return existing
        }

        let snapshot = SessionUsageSnapshot(
            childId: childId,
            startAt: startAt,
            stopAt: stopAt,
            totalSeconds: totalSeconds,
            plannedDurationSeconds: plannedDurationSeconds
        )
        snapshots.append(snapshot)
        return snapshot
    }

    func updateSnapshotScreenTimeTotals(
        _ snapshot: SessionUsageSnapshot,
        screenTimeAppTotalSeconds: Int
    ) throws {
        snapshot.screenTimeAppTotalSeconds = max(0, screenTimeAppTotalSeconds)
        snapshot.fetchedAt = Date()
    }

    func snapshots(for childId: UUID, on day: Date) throws -> [SessionUsageSnapshot] {
        let calendar = Calendar.current
        return snapshots.filter {
            $0.childId == childId && calendar.isDate($0.stopAt, inSameDayAs: day)
        }
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
