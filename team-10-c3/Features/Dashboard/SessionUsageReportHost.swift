import SwiftUI
import DeviceActivity
import FamilyControls

struct SessionUsageReportHost: View {
    let childId: UUID
    let startAt: Date
    let stopAt: Date

    private var filter: DeviceActivityFilter {
        let selection = FamilyActivitySelectionStore.load()
        return DeviceActivityFilter(
            segment: .daily(
                during: DateInterval(start: startAt, end: stopAt)
            ),
            devices: .init([.iPhone, .iPad]),
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens
        )
    }

    var body: some View {
        DeviceActivityReport(
            DeviceActivityReport.Context("sessionUsage"),
            filter: filter
        )
        .frame(width: 1, height: 1)
        .opacity(0.01)
        .accessibilityHidden(true)
    }
}
