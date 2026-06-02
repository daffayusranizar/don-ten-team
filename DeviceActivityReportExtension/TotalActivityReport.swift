import DeviceActivity
import ExtensionKit
import FamilyControls
import ManagedSettings
import SwiftUI

extension DeviceActivityReport.Context {
    static let sessionUsage = Self("sessionUsage")
}

struct TotalActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .sessionUsage

    let content: (String) -> TotalActivityView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> String {
        if let payload = await aggregateUsage(from: data) {
            SessionUsagePayloadWriter.write(payload)
        } else {
            SessionUsagePayloadWriter.writeFromAppGroup()
        }
        return "Session Usage"
    }

    private func aggregateUsage(from data: DeviceActivityResults<DeviceActivityData>) async -> SessionUsagePayload? {
        guard let query = readQueryFromAppGroup() else { return nil }

        var totals: [String: (name: String, seconds: Int)] = [:]

        for await activityData in data {
            for await segment in activityData.activitySegments {
                for await category in segment.categories {
                    for await application in category.applications {
                        let seconds = Int(application.totalActivityDuration)
                        guard seconds > 0 else { continue }

                        let name = application.application.localizedDisplayName ?? "App"
                        let key = application.application.token.debugDescription
                        let existing = totals[key]?.seconds ?? 0
                        totals[key] = (name, existing + seconds)
                    }
                }
            }
        }

        guard !totals.isEmpty else { return nil }

        let apps = totals.map { key, value in
            AppUsageRow(
                displayName: value.name,
                bundleIdentifier: key,
                durationSeconds: value.seconds
            )
        }
        .sorted { $0.durationSeconds > $1.durationSeconds }

        let totalSeconds = apps.map(\.durationSeconds).reduce(0, +)
        return SessionUsagePayload(
            childId: query.childId,
            startAt: query.startAt,
            stopAt: query.stopAt,
            totalSeconds: totalSeconds,
            apps: apps
        )
    }

    private func readQueryFromAppGroup() -> (childId: UUID, startAt: Date, stopAt: Date)? {
        let appGroupID = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String
            ?? ScreenTimeConstants.appGroupID
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let childIdString = defaults.string(forKey: ScreenTimeConstants.queryChildIdKey),
              let childId = UUID(uuidString: childIdString) else {
            return nil
        }

        let startAt = Date(timeIntervalSince1970: defaults.double(forKey: ScreenTimeConstants.queryStartKey))
        let stopAt = Date(timeIntervalSince1970: defaults.double(forKey: ScreenTimeConstants.queryEndKey))
        guard stopAt > startAt else { return nil }
        return (childId, startAt, stopAt)
    }
}

struct TotalActivityView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption)
            .onAppear {
                SessionUsagePayloadWriter.writeFromAppGroup()
            }
    }
}
