import FamilyControls
import Foundation
import ManagedSettings

enum FamilyActivitySelectionStore {
    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: ScreenTimeConstants.appGroupID)
    }

    static func load() -> FamilyActivitySelection {
        guard let defaults,
              let data = defaults.data(forKey: ScreenTimeConstants.familySelectionKey),
              let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return FamilyActivitySelection()
        }
        return selection
    }

    static var hasAllowedApps: Bool {
        let selection = load()
        return !selection.applicationTokens.isEmpty
    }

    static var allowedAppCount: Int {
        load().applicationTokens.count
    }

    /// Tokens used for session allowlist shields (apps only — categories are not supported for allowlist).
    static func allowedApplicationTokensForShields() -> Set<ApplicationToken> {
        load().applicationTokens
    }

    static func save(_ selection: FamilyActivitySelection) {
        guard let defaults,
              let data = try? PropertyListEncoder().encode(selection) else {
            return
        }
        defaults.set(data, forKey: ScreenTimeConstants.familySelectionKey)
        defaults.synchronize()
    }

    /// Stale encoded tokens can crash system Screen Time APIs; do not reuse across launches.
    static func clearPersistedSelection() {
        defaults?.removeObject(forKey: ScreenTimeConstants.familySelectionKey)
    }
}
