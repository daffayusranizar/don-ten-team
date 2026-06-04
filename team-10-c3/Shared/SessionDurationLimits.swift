//
//  SessionDurationLimits.swift
//  team-10-c3
//

import Foundation

enum SessionDurationLimits {
    /// Short sessions allowed for testing (e.g. 5s on the setup wheel).
    static let minimumSeconds = 5

    /// `DeviceActivitySchedule` rejects intervals shorter than this (MonitoringError.intervalTooShort).
    static let minimumMonitoringSeconds = 15 * 60
}
