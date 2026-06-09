import FamilyControls
import Foundation
import ManagedSettings

/// Maps Screen Time `Application` records to bundle IDs and display names.
@available(iOS 26.4, *)
struct ApplicationIdentityResolver {
    struct LoadResult: Sendable {
        let resolver: ApplicationIdentityResolver
        let monitoredApplicationTokens: Set<ApplicationToken>
    }

    private var byToken: [ApplicationToken: (bundleId: String, displayName: String)] = [:]

    @MainActor
    static func load() async -> LoadResult {
        var resolver = ApplicationIdentityResolver()
        var monitoredTokens: Set<ApplicationToken> = []
        guard DeviceActivityUsageAggregator.hasRequiredAuthorization() else {
            return LoadResult(resolver: resolver, monitoredApplicationTokens: monitoredTokens)
        }

        do {
            let installed = try await FamilyActivityData.shared.installedApplications
            for app in installed {
                guard let token = app.token,
                      let bundleId = app.bundleIdentifier,
                      !bundleId.isEmpty else { continue }
                let name = KnownAppLabels.displayName(
                    bundleId: bundleId,
                    localized: app.localizedDisplayName
                )
                resolver.byToken[token] = (bundleId, name)
                if MonitoredAppsFilter.includes(bundleId: bundleId) {
                    monitoredTokens.insert(token)
                }
            }
            let tiktokBundles = installed.compactMap(\.bundleIdentifier).filter {
                KnownAppLabels.matches(bundleId: $0, app: .tiktok)
            }
            AgentDebugLog.log(
                hypothesisId: "C",
                location: "ApplicationIdentityResolver.load",
                message: "installed app map built",
                data: [
                    "mappedCount": String(resolver.byToken.count),
                    "monitoredTokenCount": String(monitoredTokens.count),
                    "tiktokInInstalled": String(!tiktokBundles.isEmpty),
                    "tiktokBundles": tiktokBundles.joined(separator: ","),
                ]
            )
        } catch {
            AgentDebugLog.log(
                hypothesisId: "C",
                location: "ApplicationIdentityResolver.load",
                message: "installedApplications failed",
                data: ["error": String(describing: error)]
            )
        }
        return LoadResult(resolver: resolver, monitoredApplicationTokens: monitoredTokens)
    }

    func resolve(_ application: Application) -> (bundleId: String, displayName: String)? {
        if let bundleId = application.bundleIdentifier,
           !bundleId.isEmpty,
           bundleId.contains(".") {
            let name = KnownAppLabels.displayName(
                bundleId: bundleId,
                localized: application.localizedDisplayName
            )
            return (bundleId, name)
        }

        if let token = application.token, let match = byToken[token] {
            return match
        }

        return nil
    }

    func resolveBundleIdentifier(_ raw: String) -> String {
        if raw.contains(".") { return raw }
        return raw
    }
}
