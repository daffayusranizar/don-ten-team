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
                .environment(\.sessionRepository, container.sessionRepository)
                .environment(\.profileViewModel, container.profileViewModel)
                .environment(\.sessionCoordinator, container.sessionCoordinator)
                .environment(\.kidSessionViewModel, container.kidSessionViewModel)
                .environment(\.familyControlsAuth, container.familyControlsAuth)
                .overlay {
                    if let request = container.sessionCoordinator.usageReportRequest {
                        SessionUsageReportHost(
                            childId: request.childId,
                            startAt: request.startAt,
                            stopAt: request.stopAt
                        )
                    }
                }
        }
        .modelContainer(container.modelContainer)
    }
}
