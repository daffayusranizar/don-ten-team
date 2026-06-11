import Foundation
import ManagedSettings
import SwiftUI

struct SessionUsageReportConfiguration: Sendable, Equatable {
    struct AppRow: Identifiable, Sendable, Equatable {
        let id: String
        let displayName: String
        let durationSeconds: Int
        let color: Color
        let applicationToken: ApplicationToken?
    }

    struct HourlySegment: Identifiable, Sendable, Equatable {
        let id: String
        let hour: Int
        let appName: String
        let durationSeconds: Int
        let color: Color
    }

    let title: String
    let periodTitle: String?
    let childName: String?
    let sessionElapsedSeconds: Int
    let apps: [AppRow]
    let hourlySegments: [HourlySegment]
    let totalSeconds: Int
    let isEmpty: Bool
}

enum SessionUsageReportPalette {
    private static let colors: [Color] = [
        Color(red: 0.20, green: 0.55, blue: 0.95),
        Color(red: 0.95, green: 0.35, blue: 0.30),
        Color(red: 0.35, green: 0.75, blue: 0.45),
        Color(red: 0.85, green: 0.55, blue: 0.15),
    ]

    static func color(for index: Int) -> Color {
        colors[index % colors.count]
    }
}
