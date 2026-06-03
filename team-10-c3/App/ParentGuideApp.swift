//
//  ParentGuideApp.swift
//  team-10-c3
//
//  Created by Huy Tran on 26/05/26.
//
//  [P1] @main entry, SwiftData container

import SwiftUI
import SwiftData

@main
struct ParentGuideApp: App {
    private let container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.featureFlags, container.featureFlags)
                .environment(\.childRepository, container.childRepository)
                .environment(\.profileViewModel, container.profileViewModel)
                .environment(\.kidSessionViewModel, container.kidSessionViewModel)
        }
        .modelContainer(container.modelContainer)
    }
}
