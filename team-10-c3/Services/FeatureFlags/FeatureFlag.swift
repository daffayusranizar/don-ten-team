//
//  FeatureFlag.swift
//  team-10-c3
//

import Foundation

enum FeatureFlag: String, CaseIterable, Sendable, Hashable {
    /// Example flag — remove or replace when real flags are added.
    case weeklySummary

    var metadata: FeatureFlagMetadata {
        switch self {
        case .weeklySummary:
            FeatureFlagMetadata(
                key: rawValue,
                defaultValue: false,
                description: "Weekly digest screen"
            )
        }
    }

    var storageKey: String {
        Self.storageKeyPrefix + rawValue
    }

    static let storageKeyPrefix = "featureFlag."
}

struct FeatureFlagMetadata: Sendable {
    let key: String
    let defaultValue: Bool
    let description: String
}
