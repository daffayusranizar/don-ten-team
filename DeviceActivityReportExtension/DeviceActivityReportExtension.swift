import DeviceActivity
import ExtensionKit
import SwiftUI

@main
@MainActor
struct ParentGuideActivityReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TotalActivityReport { title in
            TotalActivityView(title: title)
        }
    }
}
