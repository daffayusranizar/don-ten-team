import DeviceActivity
import ExtensionKit
import SwiftUI

@main
struct KiddlyReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        SessionTodayReport { configuration in
            SessionUsageReportView(configuration: configuration)
        }
        SessionWeekReport { configuration in
            SessionUsageReportView(configuration: configuration)
        }
    }
}
