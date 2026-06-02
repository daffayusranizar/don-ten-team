import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import SwiftUI

/// Aggregates per-app usage for a session window using Apple's official `activityData` API.
enum DeviceActivityUsageAggregator {
    struct LastPayloadSelection: Sendable {
        let filterLabel: String
        let policy: String
        let score: Int
        let appCount: Int
        let appSumSeconds: Int
    }

    private(set) static var lastPayloadSelection: LastPayloadSelection?

    private static var hostAppBundleIdentifier: String? {
        Bundle.main.bundleIdentifier
    }

    static func refreshAuthorizationStatus() {
        _ = AuthorizationCenter.shared.authorizationStatus
    }

    static func hasRequiredAuthorization() -> Bool {
        let status = AuthorizationCenter.shared.authorizationStatus
        if #available(iOS 26.4, *) {
            return status == .approvedWithDataAccess
        }
        return status == .approved
    }

    static func authorizationStatusLabel() -> String {
        String(describing: AuthorizationCenter.shared.authorizationStatus)
    }

    static func aggregate(
        childId: UUID,
        startAt: Date,
        stopAt: Date
    ) async throws -> SessionUsagePayload {
        guard #available(iOS 26.4, *) else {
            return emptyPayload(childId: childId, startAt: startAt, stopAt: stopAt)
        }
        return try await aggregateFromActivityData(
            childId: childId,
            startAt: startAt,
            stopAt: stopAt
        )
    }

    @available(iOS 26.4, *)
    private static func aggregateFromActivityData(
        childId: UUID,
        startAt: Date,
        stopAt: Date
    ) async throws -> SessionUsagePayload {
        let identity = await ApplicationIdentityResolver.load()
        let labeledFilters = SessionActivityFilterBuilder.filters(startAt: startAt, stopAt: stopAt)
        let wallClockSeconds = max(1, Int(stopAt.timeIntervalSince(startAt)))

        ScreenTimePipelineLogger.logInput(
            childId: childId,
            startAt: startAt,
            stopAt: stopAt,
            filterLabels: labeledFilters.map(\.label),
            wallClockSeconds: wallClockSeconds
        )

        var scoredCandidates: [(payload: SessionUsagePayload, filterLabel: String, policy: String)] = []

        for labeled in labeledFilters {
            for policy in [DeviceActivityData.Policy.live, .cached] {
                do {
                    let payload = try await load(
                        childId: childId,
                        startAt: startAt,
                        stopAt: stopAt,
                        wallClockSeconds: wallClockSeconds,
                        filter: labeled.filter,
                        filterLabel: labeled.label,
                        policy: policy,
                        identity: identity
                    )
                    ScreenTimePipelineLogger.logCandidate(
                        filterLabel: labeled.label,
                        policy: String(describing: policy),
                        apps: payload.apps
                    )
                    if !payload.apps.isEmpty {
                        scoredCandidates.append((
                            payload,
                            labeled.label,
                            String(describing: policy)
                        ))
                    }
                } catch {
                    AgentDebugLog.log(
                        hypothesisId: "C",
                        location: "DeviceActivityUsageAggregator.aggregateFromActivityData",
                        message: "filter attempt failed — trying next",
                        data: [
                            "error": String(describing: error),
                            "policy": String(describing: policy),
                            "filterLabel": labeled.label,
                            "applicationTokenCount": String(labeled.filter.applications.count),
                        ]
                    )
                }
            }
        }

        let selected = ScreenTimePayloadSelector.selectBest(
            from: scoredCandidates,
            wallClockSeconds: wallClockSeconds
        )

        let richestFallback = scoredCandidates.max(by: {
            let lhs = $0.payload.apps.map(\.durationSeconds).reduce(0, +)
            let rhs = $1.payload.apps.map(\.durationSeconds).reduce(0, +)
            if lhs != rhs { return lhs < rhs }
            return $0.payload.apps.count < $1.payload.apps.count
        })?.payload

        let base = selected?.payload
            ?? richestFallback
            ?? emptyPayload(childId: childId, startAt: startAt, stopAt: stopAt)

        if let selected {
            let appSum = selected.payload.apps.map(\.durationSeconds).reduce(0, +)
            lastPayloadSelection = LastPayloadSelection(
                filterLabel: selected.filterLabel,
                policy: selected.policy,
                score: selected.score,
                appCount: selected.payload.apps.count,
                appSumSeconds: appSum
            )
            ScreenTimePipelineLogger.logSelected(
                filterLabel: selected.filterLabel,
                policy: selected.policy,
                score: selected.score,
                apps: selected.payload.apps
            )
            AgentDebugLog.log(
                hypothesisId: "C",
                location: "DeviceActivityUsageAggregator.aggregate:selected",
                message: "selected single activityData payload",
                data: [
                    "filterLabel": selected.filterLabel,
                    "policy": selected.policy,
                    "score": String(selected.score),
                    "candidateCount": String(scoredCandidates.count),
                    "appCount": String(selected.payload.apps.count),
                    "appSumSeconds": String(appSum),
                    "wallClockSeconds": String(wallClockSeconds),
                ]
            )
        } else {
            lastPayloadSelection = nil
        }

        return base
    }

    @available(iOS 26.4, *)
    private static func load(
        childId: UUID,
        startAt: Date,
        stopAt: Date,
        wallClockSeconds: Int,
        filter: DeviceActivityFilter,
        filterLabel: String,
        policy: DeviceActivityData.Policy,
        identity: ApplicationIdentityResolver
    ) async throws -> SessionUsagePayload {
        #if DEBUG
        SessionUsageNoiseFilter.resetDebugCounters()
        #endif

        ScreenTimePipelineLogger.logFetchStart(
            filterLabel: filterLabel,
            policy: String(describing: policy)
        )

        // bundleId -> (displayName, raw sum in session); cap each app at wall-clock before save.
        var byBundle: [String: (name: String, seconds: Int)] = [:]
        var segmentCount = 0
        var overlappingSegmentCount = 0
        var applicationCount = 0

        do {
            for try await activityData in DeviceActivityData.activityData(
                filteredBy: filter,
                using: policy
            ) {
                for await segment in activityData.activitySegments {
                    segmentCount += 1
                    let segmentInterval = segment.dateInterval
                    guard SessionUsageHourMerge.overlapsSession(
                        segmentInterval: segmentInterval,
                        sessionStart: startAt,
                        sessionEnd: stopAt
                    ) else {
                        continue
                    }
                    overlappingSegmentCount += 1

                    for await category in segment.categories {
                        for await application in category.applications {
                            applicationCount += 1
                            guard let resolved = identity.resolve(application.application) else {
                                continue
                            }
                            let localized = application.application.localizedDisplayName ?? ""

                            if isHostApp(bundleId: resolved.bundleId) {
                                continue
                            }

                            let appSeconds = Int(application.totalActivityDuration.rounded())
                            guard appSeconds > 0 else { continue }

                            let userFacing = SessionUsageNoiseFilter.isUserFacingUsage(
                                bundleId: resolved.bundleId,
                                displayName: resolved.displayName
                            )

                            guard userFacing else {
                                #if DEBUG
                                SessionUsageNoiseFilter.logDropped(
                                    bundleId: resolved.bundleId,
                                    displayName: resolved.displayName,
                                    seconds: appSeconds
                                )
                                #endif
                                ScreenTimePipelineLogger.logRawAPIRow(
                                    bundleId: resolved.bundleId,
                                    displayName: resolved.displayName,
                                    localized: localized,
                                    rawSeconds: appSeconds,
                                    segmentStart: segmentInterval.start,
                                    segmentEnd: segmentInterval.end,
                                    disposition: "dropped-noise"
                                )
                                continue
                            }

                            let prior = byBundle[resolved.bundleId]?.seconds ?? 0
                            let bundleTotal = prior + appSeconds
                            byBundle[resolved.bundleId] = (resolved.displayName, bundleTotal)

                            ScreenTimePipelineLogger.logRawAPIRow(
                                bundleId: resolved.bundleId,
                                displayName: resolved.displayName,
                                localized: localized,
                                rawSeconds: appSeconds,
                                segmentStart: segmentInterval.start,
                                segmentEnd: segmentInterval.end,
                                disposition: "kept",
                                sessionCapSeconds: wallClockSeconds,
                                bucketSeconds: bundleTotal,
                                aggregation: bundleTotal > prior ? "sum" : "skip"
                            )
                        }
                    }
                }
            }
        } catch {
            AgentDebugLog.log(
                hypothesisId: "C",
                location: "DeviceActivityUsageAggregator.load",
                message: "activityData failed",
                data: [
                    "error": String(describing: error),
                    "policy": String(describing: policy),
                    "applicationTokenCount": String(filter.applications.count),
                ]
            )
            throw error
        }

        let apps = byBundle.map { bundleId, entry in
            AppUsageRow(
                displayName: entry.name,
                bundleIdentifier: bundleId,
                durationSeconds: min(entry.seconds, wallClockSeconds)
            )
        }
        .sorted { $0.durationSeconds > $1.durationSeconds }

        let totalSeconds = apps.map(\.durationSeconds).reduce(0, +)

        #if DEBUG
        let noiseDropped = SessionUsageNoiseFilter.lastDroppedNoiseCount
        #else
        let noiseDropped = 0
        #endif

        ScreenTimePipelineLogger.logFetchEnd(
            filterLabel: filterLabel,
            policy: String(describing: policy),
            segmentCount: segmentCount,
            overlappingSegmentCount: overlappingSegmentCount,
            applicationCount: applicationCount,
            uniqueApps: apps.count,
            noiseFilteredCount: noiseDropped,
            apps: apps
        )

        return SessionUsagePayload(
            childId: childId,
            startAt: startAt,
            stopAt: stopAt,
            totalSeconds: totalSeconds,
            apps: apps
        )
    }

    private static func isHostApp(bundleId: String) -> Bool {
        guard let host = hostAppBundleIdentifier?.lowercased() else { return false }
        return bundleId.lowercased() == host
    }

    private static func emptyPayload(
        childId: UUID,
        startAt: Date,
        stopAt: Date
    ) -> SessionUsagePayload {
        SessionUsagePayload(
            childId: childId,
            startAt: startAt,
            stopAt: stopAt,
            totalSeconds: 0,
            apps: []
        )
    }
}
