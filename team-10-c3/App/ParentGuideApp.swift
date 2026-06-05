//
//  ParentGuideApp.swift
//  team-10-c3
//
//  Created by Huy Tran on 26/05/26.
//
//  [P1] @main entry, SwiftData container

import SwiftUI
import SwiftData
import UserNotifications

final class AppNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

@main
struct ParentGuideApp: App {
    private let container = AppContainer()
    private let notificationDelegate = AppNotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        Task {
            await ParentGuideApp.prepareNotificationAuthorization()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onAppear {
                    RecordingReadyBridge.ensureListening()
                    SessionTimerFiredBridge.ensureListening()
                }
                .preferredColorScheme(.light)
                .environment(\.childRepository, container.childRepository)
                .environment(\.sessionRepository, container.sessionRepository)
                .environment(\.profileViewModel, container.profileViewModel)
                .environment(\.sessionCoordinator, container.sessionCoordinator)
                .environment(\.kidSessionViewModel, container.kidSessionViewModel)
                .environment(\.weeklySummaryViewModel, container.weeklySummaryViewModel)
                .environment(\.sessionAnalysisStore, container.sessionAnalysisStore)
                .environment(\.suggestionHistoryRepository, container.suggestionHistoryRepository)
                .environment(\.familyControlsAuth, container.familyControlsAuth)
        }
        .modelContainer(container.modelContainer)
    }

    private static func prepareNotificationAuthorization() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            BroadcastExtensionLog.append("🔔 Notification authorization requested at launch: \(granted)")
        } catch {
            BroadcastExtensionLog.append("⚠️ Notification authorization request failed: \(error.localizedDescription)")
        }
    }
}
