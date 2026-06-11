import DeviceActivity
import ExtensionKit
import SwiftUI

struct SessionTodayReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .sessionToday
    let content: (SessionUsageReportConfiguration) -> SessionUsageReportView

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> SessionUsageReportConfiguration {
        await SessionUsageReportDataProcessor.makeConfiguration(
            title: "App usage during sessions",
            representing: data
        )
    }
}
