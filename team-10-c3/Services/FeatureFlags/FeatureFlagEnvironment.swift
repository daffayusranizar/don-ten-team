//
//  FeatureFlagEnvironment.swift
//  team-10-c3
//

import SwiftUI

extension EnvironmentValues {
    @Entry var featureFlags: FeatureFlagService = FeatureFlagService(
        storage: InMemoryFeatureFlagStorage()
    )
}
