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
    let profileViewModel: ProfileViewModel
    let kidSessionViewModel: KidSessionViewModel

    init(
        featureFlags: FeatureFlagService,
        modelContainer: ModelContainer,
        childRepository: ChildRepository? = nil,
        profileViewModel: ProfileViewModel? = nil
    ) {
        self.featureFlags = featureFlags
        self.modelContainer = modelContainer
        self.childRepository = childRepository ?? SwiftDataChildRepository(
            modelContext: modelContainer.mainContext
        )
        self.profileViewModel = profileViewModel ?? ProfileViewModel(
            childRepository: self.childRepository
        )
        self.profileViewModel.loadChildren()
        self.kidSessionViewModel = KidSessionViewModel()
    }

    convenience init() {
        do {
            let modelContainer = try ModelContainer(for: Child.self)
            self.init(featureFlags: FeatureFlagService(), modelContainer: modelContainer)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
