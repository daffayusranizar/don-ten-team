import DeviceActivity
import SwiftUI

/// Embeds the full Screen Time report section as a single `DeviceActivityReport` surface.
struct SessionUsageReportSection: View {
    let context: DeviceActivityReport.Context
    let filter: DeviceActivityFilter
    var refreshToken: String
    var sectionIdentity: String
    var display: SessionReportDisplayPayload

    init(
        context: DeviceActivityReport.Context,
        filter: DeviceActivityFilter,
        refreshToken: String = "",
        sectionIdentity: String = "",
        display: SessionReportDisplayPayload = .empty
    ) {
        self.context = context
        self.filter = filter
        self.refreshToken = refreshToken
        self.sectionIdentity = sectionIdentity
        self.display = display
    }

    var body: some View {
        DeviceActivityReport(context, filter: filter)
            .id("\(sectionIdentity)-\(refreshToken)")
            .frame(maxWidth: .infinity)
            .frame(height: contentHeight)
            .allowsHitTesting(false)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("App usage report")
            .onAppear {
                SessionReportDisplayContext.write(display)
            }
            .onChange(of: refreshToken) { _, _ in
                SessionReportDisplayContext.write(display)
            }
            .onChange(of: display) { _, newValue in
                SessionReportDisplayContext.write(newValue)
            }
    }

    private var contentHeight: CGFloat {
        SessionReportEmbedLayout.estimatedHeight(
            allowedAppCount: FamilyActivitySelectionStore.allowedAppCount,
            showsSessionTime: display.sessionElapsedSeconds > 0
        )
    }
}

/// Backward-compatible alias.
typealias SessionUsageReportEmbed = SessionUsageReportSection
