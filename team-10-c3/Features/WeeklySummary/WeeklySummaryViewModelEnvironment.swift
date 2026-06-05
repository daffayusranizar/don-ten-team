import SwiftUI

private struct WeeklySummaryViewModelKey: EnvironmentKey {
    static let defaultValue: WeeklySummaryViewModel? = nil
}

extension EnvironmentValues {
    var weeklySummaryViewModel: WeeklySummaryViewModel? {
        get { self[WeeklySummaryViewModelKey.self] }
        set { self[WeeklySummaryViewModelKey.self] = newValue }
    }
}
