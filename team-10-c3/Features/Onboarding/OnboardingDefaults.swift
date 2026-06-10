//
//  OnboardingDefaults.swift
//  team-10-c3
//

import Foundation

enum OnboardingDefaults {
    /// Birthdate that yields the given age as of yesterday (start of that calendar day).
    static func defaultBirthdate(ageYears: Int, referenceDate: Date = Date(), calendar: Calendar = .current) -> Date {
        let startOfToday = calendar.startOfDay(for: referenceDate)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
        return calendar.date(byAdding: .year, value: -ageYears, to: yesterday) ?? yesterday
    }

    static var defaultChildBirthdate: Date {
        defaultBirthdate(ageYears: 10)
    }
}
