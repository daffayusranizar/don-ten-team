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
    let modelContainer: ModelContainer
    let childRepository: ChildRepository
    let sessionRepository: SessionRepository
    let profileViewModel: ProfileViewModel
    let familyControlsAuth: FamilyControlsAuthService
    let screenTimeService: ScreenTimeUsageProviding
    let sessionCoordinator: SessionCoordinator
    let sessionAnalysisStore: SessionAnalysisStore
    let kidSessionViewModel: KidSessionViewModel
    let weeklySummaryViewModel: WeeklySummaryViewModel
    let suggestionHistoryRepository: SuggestionHistoryRepository

    init(
        modelContainer: ModelContainer,
        childRepository: ChildRepository? = nil,
        sessionRepository: SessionRepository? = nil,
        profileViewModel: ProfileViewModel? = nil,
        familyControlsAuth: FamilyControlsAuthService? = nil,
        screenTimeService: ScreenTimeUsageProviding? = nil,
        sessionCoordinator: SessionCoordinator? = nil,
        sessionAnalysisStore: SessionAnalysisStore? = nil,
        kidSessionViewModel: KidSessionViewModel? = nil,
        weeklySummaryViewModel: WeeklySummaryViewModel? = nil,
        suggestionHistoryRepository: SuggestionHistoryRepository? = nil
    ) {
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
        self.sessionAnalysisStore = sessionAnalysisStore ?? SessionAnalysisStore(
            modelContext: modelContainer.mainContext
        )
        self.kidSessionViewModel = kidSessionViewModel ?? KidSessionViewModel(
            sessionCoordinator: self.sessionCoordinator,
            sessionAnalysisStore: self.sessionAnalysisStore
        )
        self.weeklySummaryViewModel = weeklySummaryViewModel ?? WeeklySummaryViewModel(
            sessionRepository: self.sessionRepository,
            sessionAnalysisStore: self.sessionAnalysisStore,
            screenTimeService: self.screenTimeService,
            familyControlsAuth: self.familyControlsAuth
        )
        self.suggestionHistoryRepository = suggestionHistoryRepository
            ?? InMemorySuggestionHistoryRepository()

        self.screenTimeService.deactivateSessionRestrictions()

        self.profileViewModel.loadChildren()
        self.kidSessionViewModel.reconcilePersistedSession(profileViewModel: self.profileViewModel)
    }

    convenience init() {
        do {
            let modelContainer = try Self.makeModelContainer()
            self.init(modelContainer: modelContainer)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    private static func makeModelContainer() throws -> ModelContainer {
        let schema = Schema([
            Child.self,
            SessionMarker.self,
            SessionUsageSnapshot.self,
            SessionAnalysisRecord.self,
            DailyInsightCacheRecord.self,
        ])
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
