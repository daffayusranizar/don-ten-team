import Foundation
import FamilyControls

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

    static func save(_ selection: FamilyActivitySelection) {
        guard let defaults,
              let data = try? PropertyListEncoder().encode(selection) else {
            return
        }
        defaults.set(data, forKey: ScreenTimeConstants.familySelectionKey)
        defaults.synchronize()
    }
}
