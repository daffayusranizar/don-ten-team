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
    let familyControlsAuth: FamilyControlsAuthService
    let screenTimeService: ScreenTimeUsageProviding
    let sessionCoordinator: SessionCoordinator
    let kidSessionViewModel: KidSessionViewModel
    let suggestionHistoryRepository: SuggestionHistoryRepository

    init(
        featureFlags: FeatureFlagService,
        modelContainer: ModelContainer,
        childRepository: ChildRepository? = nil,
        sessionRepository: SessionRepository? = nil,
        profileViewModel: ProfileViewModel? = nil,
        familyControlsAuth: FamilyControlsAuthService? = nil,
        screenTimeService: ScreenTimeUsageProviding? = nil,
        sessionCoordinator: SessionCoordinator? = nil,
        kidSessionViewModel: KidSessionViewModel? = nil,
        suggestionHistoryRepository: SuggestionHistoryRepository? = nil
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
            screenTimeService: self.screenTimeService,
            familyControlsAuth: self.familyControlsAuth
        )
        self.kidSessionViewModel = kidSessionViewModel ?? KidSessionViewModel(
            sessionCoordinator: self.sessionCoordinator
        )
        self.suggestionHistoryRepository = suggestionHistoryRepository
            ?? InMemorySuggestionHistoryRepository()

        try? self.sessionRepository.purgeLegacyMockUsageSnapshots()

        self.profileViewModel.loadChildren()
    }

    convenience init() {
        do {
            let modelContainer = try Self.makeModelContainer()
            self.init(featureFlags: FeatureFlagService(), modelContainer: modelContainer)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    private static func makeModelContainer() throws -> ModelContainer {
        let schema = Schema([Child.self, SessionMarker.self, SessionUsageSnapshot.self])
        let configuration = ModelConfiguration()
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            // Existing installs lack `screenTimeAppTotalSeconds`; recreate the local store once.
            try resetPersistentStore(configuration: configuration)
            return try ModelContainer(for: schema, configurations: configuration)
        }
    }

    private static func resetPersistentStore(configuration: ModelConfiguration) throws {
        let storeURL = configuration.url
        let fileManager = FileManager.default
        let relatedURLs = [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-wal"),
            URL(fileURLWithPath: storeURL.path + "-shm"),
        ]
        for url in relatedURLs where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
}
