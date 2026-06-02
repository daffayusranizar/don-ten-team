import FamilyControls
import Foundation
import ManagedSettings

/// Persists allow/block tokens to the App Group and applies ManagedSettings shields (main app + monitor extension).
enum SessionShieldStore {
    static let managedSettingsName = ManagedSettingsStore.Name("parentguide.session.shield")

    static func persistAndApply(allowed: Set<ApplicationToken>, blocked: Set<ApplicationToken>) {
        guard let defaults = UserDefaults(suiteName: ScreenTimeConstants.appGroupID) else { return }

        var allowedSelection = FamilyActivitySelection()
        allowedSelection.applicationTokens = allowed
        var blockedSelection = FamilyActivitySelection()
        blockedSelection.applicationTokens = blocked

        defaults.set(true, forKey: ScreenTimeConstants.sessionShieldActiveKey)
        if let data = try? PropertyListEncoder().encode(allowedSelection) {
            defaults.set(data, forKey: ScreenTimeConstants.sessionShieldAllowedKey)
        }
        if let data = try? PropertyListEncoder().encode(blockedSelection) {
            defaults.set(data, forKey: ScreenTimeConstants.sessionShieldBlockedKey)
        }
        defaults.synchronize()

        applyShields(allowed: allowed, blocked: blocked)
    }

    static func applyFromAppGroupIfActive() {
        guard let defaults = UserDefaults(suiteName: ScreenTimeConstants.appGroupID),
              defaults.bool(forKey: ScreenTimeConstants.sessionShieldActiveKey),
              let data = defaults.data(forKey: ScreenTimeConstants.sessionShieldAllowedKey),
              let allowedSelection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
        else {
            return
        }

        let blocked: Set<ApplicationToken>
        if let blockData = defaults.data(forKey: ScreenTimeConstants.sessionShieldBlockedKey),
           let blockedSelection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: blockData) {
            blocked = blockedSelection.applicationTokens
        } else {
            blocked = []
        }

        applyShields(allowed: allowedSelection.applicationTokens, blocked: blocked)
    }

    static func applyShields(allowed: Set<ApplicationToken>, blocked: Set<ApplicationToken>) {
        let store = ManagedSettingsStore(named: managedSettingsName)
        store.clearAllSettings()

        guard !allowed.isEmpty || !blocked.isEmpty else { return }

        if !allowed.isEmpty {
            store.shield.applicationCategories = .all(except: allowed)
        } else {
            store.shield.applicationCategories = .all()
        }

        if !blocked.isEmpty {
            store.shield.applications = blocked
        }

        store.shield.webDomainCategories = .all()
    }

    static func clear() {
        if let defaults = UserDefaults(suiteName: ScreenTimeConstants.appGroupID) {
            defaults.set(false, forKey: ScreenTimeConstants.sessionShieldActiveKey)
            defaults.removeObject(forKey: ScreenTimeConstants.sessionShieldAllowedKey)
            defaults.removeObject(forKey: ScreenTimeConstants.sessionShieldBlockedKey)
            defaults.synchronize()
        }
        ManagedSettingsStore(named: managedSettingsName).clearAllSettings()
    }
}
