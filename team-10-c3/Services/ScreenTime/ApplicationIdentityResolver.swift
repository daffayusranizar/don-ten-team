import FamilyControls
import Foundation
import ManagedSettings

/// Maps Screen Time `Application` records to bundle IDs and display names.
@available(iOS 26.4, *)
struct ApplicationIdentityResolver {
    private var byToken: [ApplicationToken: (bundleId: String, displayName: String)] = [:]

    static func load() async -> ApplicationIdentityResolver {
        var resolver = ApplicationIdentityResolver()
        guard DeviceActivityUsageAggregator.hasRequiredAuthorization() else {
            return resolver
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
        return resolver
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
