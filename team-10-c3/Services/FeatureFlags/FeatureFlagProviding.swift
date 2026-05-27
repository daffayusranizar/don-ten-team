//
//  FeatureFlagProviding.swift
//  team-10-c3
//

import Foundation

@MainActor
protocol FeatureFlagProviding: AnyObject {
    func isEnabled(_ flag: FeatureFlag) -> Bool
    func set(_ flag: FeatureFlag, enabled: Bool)
    func reset(_ flag: FeatureFlag)
    func setFlags(_ flags: [FeatureFlag: Bool])
    func resetAll()
    func snapshot() -> [FeatureFlag: Bool]
}
