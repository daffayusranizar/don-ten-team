//
//  RootView.swift
//  team-10-c3
//
//  Created by Huy Tran on 26/05/26.
//
// [P1] Routes: Onboarding ↔️ Dashboard

import SwiftUI

enum AppTab: Int {
    case dashboard
    case insight
    case session
}

struct RootView: View {
    @SceneStorage("selectedTab") private var selectedTab = AppTab.dashboard.rawValue
    @Environment(\.sessionCoordinator) private var sessionCoordinator
    
    @State private var showSplashScreen = true
    @State private var splashStatusMessage = "Starting Kiddly…"

    var body: some View {
        Group {
            if showSplashScreen {
                SplashScreenView(statusMessage: splashStatusMessage)
            } else {
                mainTabView
            }
        }
        .task {
            await runSplashStartup()
        }
    }

    @MainActor
    private func runSplashStartup() async {
        splashStatusMessage = "Preparing on-device audio analysis…"

        if !PreviewRuntime.isActive {
            do {
                try await WhisperModelLoader.preload()
                splashStatusMessage = "Finishing setup…"
            } catch {
                print("Whisper preload failed: \(error.localizedDescription)")
                splashStatusMessage = "Continuing without audio preload…"
            }
        } else {
            splashStatusMessage = "Loading preview…"
        }

        try? await Task.sleep(for: .milliseconds(350))

        withAnimation {
            showSplashScreen = false
        }
    }
    
    @ViewBuilder
    private var mainTabView: some View {
        @Bindable var sessionCoordinator = sessionCoordinator

        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: AppTab.dashboard.rawValue) {
                NavigationStack {
                    DashboardView()
                }
            }

            Tab("Insight", systemImage: "chart.bar.fill", value: AppTab.insight.rawValue) {
                NavigationStack {
                    WeeklySummaryView()
                }
            }

            Tab("Session", systemImage: "record.circle", value: AppTab.session.rawValue, role: .search) {
                NavigationStack {
                    SessionSetupView(
                        showsBackButton: false,
                        onSessionStarted: { selectedTab = AppTab.dashboard.rawValue }
                    )
                }
            }
        }
    }
}

#Preview {
    let repository = InMemoryChildRepository()
    let profileViewModel = ProfileViewModel(childRepository: repository)
    
    RootView()
        .environment(\.childRepository, repository)
        .environment(\.profileViewModel, profileViewModel)
        .environment(\.sessionCoordinator, SessionCoordinator(
            sessionRepository: InMemorySessionRepository(),
            screenTimeService: ScreenTimeService(),
            familyControlsAuth: PreviewFamilyControlsAuthService()
        ))
        .environment(\.kidSessionViewModel, KidSessionViewModel(
            sessionCoordinator: SessionCoordinator(
                sessionRepository: InMemorySessionRepository(),
                screenTimeService: ScreenTimeService(),
                familyControlsAuth: PreviewFamilyControlsAuthService()
            )
        ))
}
