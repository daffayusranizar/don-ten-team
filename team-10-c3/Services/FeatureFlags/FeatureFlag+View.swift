//
//  FeatureFlag+View.swift
//  team-10-c3
//

import SwiftUI

extension View {
    @ViewBuilder
    func featureGated(_ flag: FeatureFlag) -> some View {
        modifier(FeatureGatedModifier(flag: flag))
    }
}

struct FeatureGatedContent<Enabled: View, Fallback: View>: View {
    let flag: FeatureFlag
    @ViewBuilder let ifEnabled: () -> Enabled
    @ViewBuilder let fallback: () -> Fallback

    @Environment(\.featureFlags) private var featureFlags

    var body: some View {
        if featureFlags.isEnabled(flag) {
            ifEnabled()
        } else {
            fallback()
        }
    }
}

extension View {
    @ViewBuilder
    func featureGated<Fallback: View>(
        _ flag: FeatureFlag,
        @ViewBuilder else fallback: @escaping () -> Fallback
    ) -> some View {
        FeatureGatedContent(flag: flag, ifEnabled: { self }, fallback: fallback)
    }
}

private struct FeatureGatedModifier: ViewModifier {
    let flag: FeatureFlag

    @Environment(\.featureFlags) private var featureFlags

    func body(content: Content) -> some View {
        if featureFlags.isEnabled(flag) {
            content
        }
    }
}
