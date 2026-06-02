//
//  AppContainer.swift
//  team-10-c3
//
//  Created by Huy Tran on 26/05/26.
//
// [P1] Builds all actors/services at launch

import Foundation
import SwiftData

@MainActor
final class AppContainer {
    let featureFlags: FeatureFlagService
    let modelContainer: ModelContainer
    let childRepository: ChildRepository
    let sessionRepository: SessionRepository
    let profileViewModel: ProfileViewModel
    let familyControlsAuth: FamilyControlsAuthProviding
    let screenTimeService: ScreenTimeUsageProviding
    let sessionCoordinator: SessionCoordinator
    let kidSessionViewModel: KidSessionViewModel

    init(
        featureFlags: FeatureFlagService,
        modelContainer: ModelContainer,
        childRepository: ChildRepository? = nil,
        sessionRepository: SessionRepository? = nil,
        profileViewModel: ProfileViewModel? = nil,
        familyControlsAuth: FamilyControlsAuthProviding? = nil,
        screenTimeService: ScreenTimeUsageProviding? = nil,
        sessionCoordinator: SessionCoordinator? = nil,
        kidSessionViewModel: KidSessionViewModel? = nil
    ) {
        self.featureFlags = featureFlags
        self.modelContainer = modelContainer
        self.childRepository = childRepository ?? SwiftDataChildRepository(
            modelContext: modelContainer.mainContext
        )
        self.sessionRepository = sessionRepository ?? SwiftDataSessionRepository(
            modelContext: modelContainer.mainContext
        )
        self.profileViewModel = profileViewModel ?? ProfileViewModel(
            childRepository: self.childRepository
        )
        self.familyControlsAuth = familyControlsAuth ?? FamilyControlsAuthService()
        self.screenTimeService = screenTimeService ?? ScreenTimeService()
        self.sessionCoordinator = sessionCoordinator ?? SessionCoordinator(
            sessionRepository: self.sessionRepository,
            screenTimeService: self.screenTimeService
        )
        self.kidSessionViewModel = kidSessionViewModel ?? KidSessionViewModel(
            sessionCoordinator: self.sessionCoordinator
        )
        self.profileViewModel.loadChildren()
    }

    convenience init() {
        do {
            let schema = Schema([Child.self, SessionMarker.self, SessionUsageSnapshot.self])
            let modelContainer = try ModelContainer(for: schema)
            self.init(featureFlags: FeatureFlagService(), modelContainer: modelContainer)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
