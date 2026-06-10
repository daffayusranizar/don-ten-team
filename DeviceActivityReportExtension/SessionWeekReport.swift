import DeviceActivity
import ExtensionKit
import SwiftUI

struct SessionWeekReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .sessionWeek
    let content: (SessionUsageReportConfiguration) -> SessionUsageReportView

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> SessionUsageReportConfiguration {
        await SessionUsageReportDataProcessor.makeConfiguration(
            title: "App usage during sessions (week)",
            representing: data
        )
    }
}
