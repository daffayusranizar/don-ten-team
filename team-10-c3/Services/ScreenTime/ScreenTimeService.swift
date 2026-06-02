import Foundation
import DeviceActivity
import FamilyControls

@MainActor
protocol ScreenTimeUsageProviding {
    func startMonitoring(childId: UUID, startAt: Date, plannedEndAt: Date) throws
    func stopMonitoring() throws
    func fetchUsage(childId: UUID, startAt: Date, stopAt: Date) async throws -> SessionUsagePayload
}

@MainActor
final class ScreenTimeService: ScreenTimeUsageProviding {
    private let center = DeviceActivityCenter()
    private let activityName = DeviceActivityName(ScreenTimeConstants.sessionActivityName)

    private let fetchAttemptDelays: [Duration] = [.seconds(2), .seconds(4), .seconds(6)]

    func startMonitoring(childId: UUID, startAt: Date, plannedEndAt: Date) throws {
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents.from(date: startAt),
            intervalEnd: DateComponents.from(date: plannedEndAt),
            repeats: false
        )

        try center.startMonitoring(activityName, during: schedule)
    }

    func stopMonitoring() throws {
        center.stopMonitoring([activityName])
    }

    func fetchUsage(childId: UUID, startAt: Date, stopAt: Date) async throws -> SessionUsagePayload {
        DeviceActivityUsageAggregator.refreshAuthorizationStatus()
        let status = AuthorizationCenter.shared.authorizationStatus

        AgentDebugLog.log(
            hypothesisId: "B",
            location: "ScreenTimeService.fetchUsage:start",
            message: "fetchUsage via activityData",
            data: [
                "childId": childId.uuidString,
                "authorizationStatus": String(describing: status),
                "hasUsageDataAccess": String(DeviceActivityUsageAggregator.hasRequiredAuthorization()),
                "startAt": ISO8601DateFormatter().string(from: startAt),
                "stopAt": ISO8601DateFormatter().string(from: stopAt),
            ]
        )

        guard DeviceActivityUsageAggregator.hasRequiredAuthorization() else {
            AgentDebugLog.log(
                hypothesisId: "B",
                location: "ScreenTimeService.fetchUsage:unauthorized",
                message: "missing approvedWithDataAccess",
                data: ["authorizationStatus": String(describing: status)]
            )
            throw ScreenTimeFetchError.missingUsageDataAccess(
                status: DeviceActivityUsageAggregator.authorizationStatusLabel()
            )
        }

        let wallClockSeconds = max(1, Int(stopAt.timeIntervalSince(startAt)))
        var best: SessionUsagePayload?
        var lastError: Error?

        for delay in fetchAttemptDelays {
            try await Task.sleep(for: delay)
            do {
                let payload = try await DeviceActivityUsageAggregator.aggregate(
                    childId: childId,
                    startAt: startAt,
                    stopAt: stopAt
                )
                best = ScreenTimePayloadSelector.preferRicher(
                    existing: best,
                    new: payload,
                    wallClockSeconds: wallClockSeconds
                )
                if usageBackfillIsRichEnough(best?.apps ?? []) { break }
            } catch {
                lastError = error
                AgentDebugLog.log(
                    hypothesisId: "D",
                    location: "ScreenTimeService.fetchUsage:attempt",
                    message: "activityData attempt failed",
                    data: ["error": String(describing: error)]
                )
            }
        }

        let merged: SessionUsagePayload
        if let best {
            merged = best
        } else if let lastError {
            throw ScreenTimeFetchError.activityDataUnavailable(String(describing: lastError))
        } else {
            merged = SessionUsagePayload(
                childId: childId,
                startAt: startAt,
                stopAt: stopAt,
                totalSeconds: 0,
                apps: []
            )
        }

        let sanitized = SessionUsageSanitizer.sanitizedPayload(merged)
        ScreenTimePipelineLogger.logOutput(
            stage: "afterSanitize",
            apps: sanitized.apps,
            sessionElapsedSeconds: wallClockSeconds,
            extra: [
                "payloadTotalSeconds": String(sanitized.totalSeconds),
                "hasTikTok": String(sanitized.apps.contains {
                    KnownAppLabels.matches(bundleId: $0.bundleIdentifier, app: .tiktok)
                }),
            ]
        )
        AgentDebugLog.log(
            hypothesisId: "D",
            location: "ScreenTimeService.fetchUsage:success",
            message: "activityData payload",
            data: [
                "appCount": String(sanitized.apps.count),
                "totalSeconds": String(sanitized.totalSeconds),
                "appsList": ScreenTimePipelineLogger.formatApps(sanitized.apps),
                "hasTikTok": String(sanitized.apps.contains {
                    KnownAppLabels.matches(bundleId: $0.bundleIdentifier, app: .tiktok)
                }),
                "topBundles": sanitized.apps.prefix(5).map(\.bundleIdentifier).joined(separator: ","),
            ]
        )
        return sanitized
    }
}

private func usageBackfillIsRichEnough(_ apps: [AppUsageRow]) -> Bool {
    apps.contains { $0.durationSeconds >= 30 }
}

private extension DateComponents {
    static func from(date: Date) -> DateComponents {
        Calendar.current.dateComponents([.hour, .minute, .second], from: date)
    }
}
