import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import SwiftUI

/// Aggregates per-app usage using hourly `activityData` queries.
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

    /// EU + EEA storefront/region codes where customer installs can reach `approvedWithDataAccess`.
    private static let euRegionCodes: Set<String> = [
        "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "GR", "HU",
        "IE", "IT", "LV", "LT", "LU", "MT", "NL", "PL", "PT", "RO", "SK", "SI", "ES", "SE",
        "IS", "LI", "NO",
    ]

    /// Apple only grants `approvedWithDataAccess` on EU devices with an EU Apple Account.
    static var isDeviceInEURegion: Bool {
        let code = Locale.current.region?.identifier.uppercased() ?? ""
        return euRegionCodes.contains(code)
    }

    /// True when usage fetch proceeds with basic `approved` because data access is unavailable outside the EU.
    static var usesApprovedOnlyFallback: Bool {
        guard #available(iOS 26.4, *) else { return false }
        let status = AuthorizationCenter.shared.authorizationStatus
        return status == .approved && !isDeviceInEURegion
    }

    static func refreshAuthorizationStatus() {
        _ = AuthorizationCenter.shared.authorizationStatus
    }

    static func hasRequiredAuthorization() -> Bool {
        let status = AuthorizationCenter.shared.authorizationStatus
        if #available(iOS 26.4, *) {
            if status == .approvedWithDataAccess {
                return true
            }
            // Outside the EU, customer installs never reach `approvedWithDataAccess`.
            if status == .approved, !isDeviceInEURegion {
                return true
            }
            return false
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

    /// Live hourly fetch for chart: union hours across sessions, one query per hour.
    static func aggregateHourlyForSessions(
        childId: UUID,
        sessions: [SessionWindow]
    ) async throws -> HourlyChartUsageResult {
        guard #available(iOS 26.4, *) else {
            return HourlyChartUsageResult(hourlyApps: [], apps: [])
        }
        let windows = sessions.map { (startAt: $0.startAt, stopAt: $0.stopAt) }
        guard !windows.isEmpty else {
            return HourlyChartUsageResult(hourlyApps: [], apps: [])
        }

        let identityLoad = await ApplicationIdentityResolver.load()
        let identity = identityLoad.resolver
        var monitoredTokens = identityLoad.monitoredApplicationTokens
        if monitoredTokens.isEmpty {
            monitoredTokens = FamilyActivitySelectionStore.allowedApplicationTokensForShields()
        }
        let calendar = Calendar.current
        let hourStarts = SessionUsageHourMerge.unionHourStarts(sessions: windows, calendar: calendar)
        let capSeconds = 3600

        ScreenTimePipelineLogger.logInput(
            childId: childId,
            startAt: windows.map(\.startAt).min() ?? Date(),
            stopAt: windows.map(\.stopAt).max() ?? Date(),
            filterLabels: hourStarts.map { "hourly+\(ISO8601DateFormatter().string(from: $0))" },
            wallClockSeconds: capSeconds
        )

        var mergedHourly: [Date: [String: (name: String, seconds: Int)]] = [:]
        var lastSelected: ScreenTimePayloadSelector.Candidate?

        for hourStart in hourStarts {
            guard let labeled = SessionActivityFilterBuilder.filterForHour(
                hourStart: hourStart,
                applications: monitoredTokens,
                calendar: calendar
            ) else {
                continue
            }

            var hourCandidates: [(payload: SessionUsagePayload, filterLabel: String, policy: String)] = []

            for policy in [DeviceActivityData.Policy.live, .cached] {
                do {
                    let payload = try await load(
                        childId: childId,
                        sessions: windows,
                        hourStart: hourStart,
                        capSeconds: capSeconds,
                        filter: labeled.filter,
                        filterLabel: labeled.label,
                        policy: policy,
                        identity: identity,
                        monitoredTokens: monitoredTokens
                    )
                    ScreenTimePipelineLogger.logCandidate(
                        filterLabel: labeled.label,
                        policy: String(describing: policy),
                        apps: payload.apps
                    )
                    if !payload.apps.isEmpty {
                        hourCandidates.append((
                            payload,
                            labeled.label,
                            String(describing: policy)
                        ))
                    }
                } catch {
                    AgentDebugLog.log(
                        hypothesisId: "C",
                        location: "DeviceActivityUsageAggregator.aggregateHourlyForSessions",
                        message: "hourly filter attempt failed",
                        data: [
                            "error": String(describing: error),
                            "policy": String(describing: policy),
                            "filterLabel": labeled.label,
                        ]
                    )
                }
            }

            guard let hourBest = ScreenTimePayloadSelector.selectBest(
                from: hourCandidates,
                wallClockSeconds: capSeconds
            ) else {
                continue
            }

            lastSelected = hourBest
            var hourBucket = mergedHourly[hourStart] ?? [:]
            for app in hourBest.payload.apps {
                guard app.durationSeconds > 0 else { continue }
                hourBucket[app.bundleIdentifier] = (app.displayName, app.durationSeconds)
            }
            mergedHourly[hourStart] = hourBucket
        }

        let hourlyApps = mergedHourly.flatMap { hourStart, bucket -> [HourlyAppUsageRow] in
            let hour = calendar.component(.hour, from: hourStart)
            return bucket.map { bundleId, entry in
                HourlyAppUsageRow(
                    hour: hour,
                    displayName: entry.name,
                    bundleIdentifier: bundleId,
                    durationSeconds: entry.seconds
                )
            }
        }

        let apps = SessionUsageHourMerge.mergedApps(from: hourlyApps)

        if let lastSelected {
            lastPayloadSelection = LastPayloadSelection(
                filterLabel: lastSelected.filterLabel,
                policy: lastSelected.policy,
                score: lastSelected.score,
                appCount: apps.count,
                appSumSeconds: apps.map(\.durationSeconds).reduce(0, +)
            )
            ScreenTimePipelineLogger.logSelected(
                filterLabel: "hourly-day(\(hourStarts.count)h)",
                policy: lastSelected.policy,
                score: lastSelected.score,
                apps: apps
            )
        } else {
            lastPayloadSelection = nil
        }

        return HourlyChartUsageResult(hourlyApps: hourlyApps, apps: apps)
    }

    @available(iOS 26.4, *)
    private static func aggregateFromActivityData(
        childId: UUID,
        startAt: Date,
        stopAt: Date
    ) async throws -> SessionUsagePayload {
        let result = try await aggregateHourlyForSessions(
            childId: childId,
            sessions: [SessionWindow(startAt: startAt, stopAt: stopAt)]
        )
        let wallClockSeconds = max(1, Int(stopAt.timeIntervalSince(startAt)))
        let apps = result.apps.map { app in
            AppUsageRow(
                displayName: app.displayName,
                bundleIdentifier: app.bundleIdentifier,
                durationSeconds: min(app.durationSeconds, wallClockSeconds)
            )
        }
        .sorted { $0.durationSeconds > $1.durationSeconds }

        return SessionUsagePayload(
            childId: childId,
            startAt: startAt,
            stopAt: stopAt,
            totalSeconds: apps.map(\.durationSeconds).reduce(0, +),
            apps: apps
        )
    }

    @available(iOS 26.4, *)
    private static func load(
        childId: UUID,
        sessions: [(startAt: Date, stopAt: Date)],
        hourStart: Date,
        capSeconds: Int,
        filter: DeviceActivityFilter,
        filterLabel: String,
        policy: DeviceActivityData.Policy,
        identity: ApplicationIdentityResolver,
        monitoredTokens: Set<ApplicationToken>
    ) async throws -> SessionUsagePayload {
        #if DEBUG
        SessionUsageNoiseFilter.resetDebugCounters()
        #endif

        ScreenTimePipelineLogger.logFetchStart(
            filterLabel: filterLabel,
            policy: String(describing: policy)
        )

        var byBundle: [String: (name: String, seconds: Int)] = [:]
        var segmentCount = 0
        var overlappingSegmentCount = 0
        var applicationCount = 0

        let rangeStart = sessions.map(\.startAt).min() ?? hourStart
        let rangeEnd = sessions.map(\.stopAt).max() ?? hourStart

        do {
            for try await activityData in DeviceActivityData.activityData(
                filteredBy: filter,
                using: policy
            ) {
                for await segment in activityData.activitySegments {
                    segmentCount += 1
                    let segmentInterval = segment.dateInterval
                    guard SessionUsageHourMerge.segmentOverlapsAnySession(
                        segmentInterval: segmentInterval,
                        sessions: sessions,
                        hourStart: hourStart
                    ) else {
                        continue
                    }
                    overlappingSegmentCount += 1

                    for await category in segment.categories {
                        for await application in category.applications {
                            applicationCount += 1
                            guard let resolved = resolveApplication(
                                application.application,
                                identity: identity,
                                monitoredTokens: monitoredTokens
                            ) else {
                                continue
                            }
                            let localized = application.application.localizedDisplayName ?? ""

                            if isHostApp(bundleId: resolved.bundleId) {
                                continue
                            }

                            let appSeconds = Int(application.totalActivityDuration.rounded())
                            guard appSeconds > 0 else { continue }

                            let isMonitored = isMonitoredApplication(
                                application.application,
                                resolved: resolved,
                                monitoredTokens: monitoredTokens
                            )

                            guard isMonitored else {
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
                                    disposition: "dropped-noise",
                                    hourBucketStart: hourStart
                                )
                                continue
                            }

                            let prior = byBundle[resolved.bundleId]?.seconds ?? 0
                            let hourly = SessionUsageHourMerge.maxInHourBucket(
                                existing: prior,
                                added: appSeconds
                            )
                            byBundle[resolved.bundleId] = (resolved.displayName, hourly)

                            ScreenTimePipelineLogger.logRawAPIRow(
                                bundleId: resolved.bundleId,
                                displayName: resolved.displayName,
                                localized: localized,
                                rawSeconds: appSeconds,
                                segmentStart: segmentInterval.start,
                                segmentEnd: segmentInterval.end,
                                disposition: "kept",
                                hourBucketStart: hourStart,
                                sessionCapSeconds: capSeconds,
                                bucketSeconds: hourly,
                                aggregation: hourly > prior ? "max" : "skip"
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
                    "filterLabel": filterLabel,
                ]
            )
            throw error
        }

        let apps = byBundle.map { bundleId, entry in
            AppUsageRow(
                displayName: entry.name,
                bundleIdentifier: bundleId,
                durationSeconds: min(entry.seconds, capSeconds)
            )
        }
        .sorted { $0.durationSeconds > $1.durationSeconds }

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
            startAt: rangeStart,
            stopAt: rangeEnd,
            totalSeconds: apps.map(\.durationSeconds).reduce(0, +),
            apps: apps
        )
    }

    private static func isHostApp(bundleId: String) -> Bool {
        guard let host = hostAppBundleIdentifier?.lowercased() else { return false }
        return bundleId.lowercased() == host
    }

    @available(iOS 26.4, *)
    private static func resolveApplication(
        _ application: Application,
        identity: ApplicationIdentityResolver,
        monitoredTokens: Set<ApplicationToken>
    ) -> (bundleId: String, displayName: String)? {
        if let resolved = identity.resolve(application) {
            return resolved
        }
        guard usesApprovedOnlyFallback,
              let token = application.token,
              monitoredTokens.contains(token) else {
            return nil
        }
        let localized = application.localizedDisplayName ?? "App"
        let bundleId = bundleIdForOpaqueMonitoredApp(localized: localized)
            ?? "monitored.\(abs(token.hashValue))"
        MonitoredAppsFilter.noteResolvedBundleId(bundleId)
        let displayName = KnownAppLabels.displayName(bundleId: bundleId, localized: localized)
        return (bundleId, displayName)
    }

    @available(iOS 26.4, *)
    private static func isMonitoredApplication(
        _ application: Application,
        resolved: (bundleId: String, displayName: String),
        monitoredTokens: Set<ApplicationToken>
    ) -> Bool {
        if let token = application.token, monitoredTokens.contains(token) {
            return true
        }
        return MonitoredAppsFilter.includes(bundleId: resolved.bundleId)
    }

    private static func bundleIdForOpaqueMonitoredApp(localized: String) -> String? {
        let lower = localized.lowercased()
        if lower.contains("thread") {
            return "com.instagram.barcelona"
        }
        if lower.contains("tiktok") {
            return "com.zhiliaoapp.musically"
        }
        if lower.contains("youtube") {
            return "com.google.ios.youtube"
        }
        return nil
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
