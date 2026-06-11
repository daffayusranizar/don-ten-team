import Foundation

/// Display-only metadata shared from the main app to the report extension (not usage payloads).
struct SessionReportDisplayPayload: Sendable, Equatable {
    var periodTitle: String?
    var childName: String?
    var sessionElapsedSeconds: Int

    static let empty = SessionReportDisplayPayload(
        periodTitle: nil,
        childName: nil,
        sessionElapsedSeconds: 0
    )
}

enum SessionReportDisplayContext {
    private static let periodTitleKey = "sessionReport.periodTitle"
    private static let childNameKey = "sessionReport.childName"
    private static let sessionElapsedKey = "sessionReport.sessionElapsedSeconds"
    private static let renderedAppRowCountKey = "sessionReport.renderedAppRowCount"
    private static let renderedIsEmptyKey = "sessionReport.renderedIsEmpty"
    private static let renderedShowsHourlyChartKey = "sessionReport.renderedShowsHourlyChart"
    private static let renderedHasRenderedKey = "sessionReport.renderedHasRendered"

    static func write(_ payload: SessionReportDisplayPayload) {
        guard let defaults = sharedDefaults else { return }
        defaults.set(payload.periodTitle, forKey: periodTitleKey)
        defaults.set(payload.childName, forKey: childNameKey)
        defaults.set(payload.sessionElapsedSeconds, forKey: sessionElapsedKey)
    }

    static func read() -> SessionReportDisplayPayload {
        guard let defaults = sharedDefaults else { return .empty }
        return SessionReportDisplayPayload(
            periodTitle: defaults.string(forKey: periodTitleKey),
            childName: defaults.string(forKey: childNameKey),
            sessionElapsedSeconds: defaults.integer(forKey: sessionElapsedKey)
        )
    }

    static func writeRenderedMetrics(
        appRowCount: Int,
        isEmpty: Bool,
        showsHourlyChart: Bool
    ) {
        guard let defaults = sharedDefaults else { return }
        defaults.set(appRowCount, forKey: renderedAppRowCountKey)
        defaults.set(isEmpty, forKey: renderedIsEmptyKey)
        defaults.set(showsHourlyChart, forKey: renderedShowsHourlyChartKey)
        defaults.set(true, forKey: renderedHasRenderedKey)
        defaults.synchronize()
    }

    static func clearRenderedMetrics() {
        guard let defaults = sharedDefaults else { return }
        defaults.removeObject(forKey: renderedAppRowCountKey)
        defaults.removeObject(forKey: renderedIsEmptyKey)
        defaults.removeObject(forKey: renderedShowsHourlyChartKey)
        defaults.removeObject(forKey: renderedHasRenderedKey)
    }

    static func readRenderedMetrics() -> SessionReportRenderedMetrics {
        guard let defaults = sharedDefaults else { return .unknown }
        return SessionReportRenderedMetrics(
            appRowCount: defaults.integer(forKey: renderedAppRowCountKey),
            isEmpty: defaults.bool(forKey: renderedIsEmptyKey),
            showsHourlyChart: defaults.bool(forKey: renderedShowsHourlyChartKey),
            hasRendered: defaults.bool(forKey: renderedHasRenderedKey)
        )
    }

    private static var sharedDefaults: UserDefaults? {
        let groupID = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String
        guard let groupID, !groupID.isEmpty else { return nil }
        return UserDefaults(suiteName: groupID)
    }
}
