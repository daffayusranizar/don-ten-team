//
//  FeatureFlagStorage.swift
//  team-10-c3
//

import Foundation

protocol FeatureFlagStorage: Sendable {
    func storedValue(forKey key: String) -> Bool?
    func setStoredValue(_ value: Bool?, forKey key: String)
}

struct UserDefaultsFeatureFlagStorage: FeatureFlagStorage {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func storedValue(forKey key: String) -> Bool? {
        guard userDefaults.object(forKey: key) != nil else {
            return nil
        }
        return userDefaults.bool(forKey: key)
    }

    func setStoredValue(_ value: Bool?, forKey key: String) {
        if let value {
            userDefaults.set(value, forKey: key)
        } else {
            userDefaults.removeObject(forKey: key)
        }
    }
}

final class InMemoryFeatureFlagStorage: FeatureFlagStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Bool]

    init(initial: [FeatureFlag: Bool] = [:]) {
        values = Dictionary(uniqueKeysWithValues: initial.map { ($0.key.storageKey, $0.value) })
    }

    func storedValue(forKey key: String) -> Bool? {
        lock.withLock { values[key] }
    }

    func setStoredValue(_ value: Bool?, forKey key: String) {
        lock.withLock {
            if let value {
                values[key] = value
            } else {
                values.removeValue(forKey: key)
            }
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
