import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

private enum MonitorShieldKeys {
    static var appGroupID: String {
        Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String
            ?? "group.abui.don-ten-team.shared"
    }

    static let active = "sessionShieldActive"
    static let allowed = "sessionShieldAllowed"
    static let blocked = "sessionShieldBlocked"
    static let activityName = "parentguide.kid.session"
    static let storeName = ManagedSettingsStore.Name("parentguide.session.shield")
}

final class SessionDeviceActivityMonitor: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard activity.rawValue == MonitorShieldKeys.activityName else { return }
        applyShieldFromAppGroup()
        writeHeartbeat("intervalDidStart")
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity.rawValue == MonitorShieldKeys.activityName else { return }
        ManagedSettingsStore(named: MonitorShieldKeys.storeName).clearAllSettings()
        writeHeartbeat("intervalDidEnd")
    }

    private func applyShieldFromAppGroup() {
        guard let defaults = UserDefaults(suiteName: MonitorShieldKeys.appGroupID),
              defaults.bool(forKey: MonitorShieldKeys.active),
              let data = defaults.data(forKey: MonitorShieldKeys.allowed),
              let allowed = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
        else {
            return
        }

        let blocked: Set<ApplicationToken>
        if let blockData = defaults.data(forKey: MonitorShieldKeys.blocked),
           let blockedSelection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: blockData) {
            blocked = blockedSelection.applicationTokens
        } else {
            blocked = []
        }

        let store = ManagedSettingsStore(named: MonitorShieldKeys.storeName)
        store.clearAllSettings()

        if !allowed.applicationTokens.isEmpty {
            store.shield.applicationCategories = .all(except: allowed.applicationTokens)
        } else {
            store.shield.applicationCategories = .all()
        }
        if !blocked.isEmpty {
            store.shield.applications = blocked
        }
        store.shield.webDomainCategories = .all()
    }

    private func writeHeartbeat(_ event: String) {
        guard let defaults = UserDefaults(suiteName: MonitorShieldKeys.appGroupID) else { return }
        defaults.set(event, forKey: "deviceActivityExtensionHeartbeat")
        defaults.set(Date().timeIntervalSince1970, forKey: "deviceActivityExtensionHeartbeatAt")
        defaults.synchronize()
    }
}
