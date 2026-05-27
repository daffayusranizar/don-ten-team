//
//  AppContainer.swift
//  team-10-c3
//
//  Created by Huy Tran on 26/05/26.
//
// [P1] Builds all actors/services at launch

import Foundation

@MainActor
final class AppContainer {
    let featureFlags: FeatureFlagService

    init(featureFlags: FeatureFlagService) {
        self.featureFlags = featureFlags
    }

    convenience init() {
        self.init(featureFlags: FeatureFlagService())
    }
}
