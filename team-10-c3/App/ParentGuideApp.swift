//
//  ParentGuideApp.swift
//  team-10-c3
//
//  Created by Huy Tran on 26/05/26.
//
//  [P1] @main entry, SwiftData container

import SwiftUI

@main
struct ParentGuideApp: App {
    private let container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.featureFlags, container.featureFlags)
        }
    }
}
