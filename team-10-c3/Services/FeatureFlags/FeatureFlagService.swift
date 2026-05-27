//
//  FeatureFlagService.swift
//  team-10-c3
//

import Foundation
import Observation

@Observable
@MainActor
final class FeatureFlagService: FeatureFlagProviding {
    private let storage: FeatureFlagStorage
    private var cache: [String: Bool]

    init(storage: FeatureFlagStorage = UserDefaultsFeatureFlagStorage()) {
        self.storage = storage
        self.cache = [:]

        for flag in FeatureFlag.allCases {
            if let storedValue = storage.storedValue(forKey: flag.storageKey) {
                cache[flag.storageKey] = storedValue
            }
        }
    }

    func isEnabled(_ flag: FeatureFlag) -> Bool {
        if let cachedValue = cache[flag.storageKey] {
            return cachedValue
        }
        return flag.metadata.defaultValue
    }

    func set(_ flag: FeatureFlag, enabled: Bool) {
        cache[flag.storageKey] = enabled
        storage.setStoredValue(enabled, forKey: flag.storageKey)
    }

    func reset(_ flag: FeatureFlag) {
        cache.removeValue(forKey: flag.storageKey)
        storage.setStoredValue(nil, forKey: flag.storageKey)
    }

    func setFlags(_ flags: [FeatureFlag: Bool]) {
        for (flag, enabled) in flags {
            set(flag, enabled: enabled)
        }
    }

    func resetAll() {
        for flag in FeatureFlag.allCases {
            reset(flag)
        }
    }

    func snapshot() -> [FeatureFlag: Bool] {
        Dictionary(uniqueKeysWithValues: FeatureFlag.allCases.map { flag in
            (flag, isEnabled(flag))
        })
    }
}
