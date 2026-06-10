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
    case guidance
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
        if PreviewRuntime.isActive {
            splashStatusMessage = "Loading preview…"
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation { showSplashScreen = false }
            return
        }

        var clipLoaded = false
        var whisperLoaded = false

        splashStatusMessage = "Loading screen analysis model…"
        await Task.yield()
        do {
            try await MobileCLIPModelLoader.preload()
            clipLoaded = true
        } catch {
            print("MobileCLIP preload failed: \(error.localizedDescription)")
        }

        do {
            try await WhisperModelLoader.preload { status in
                Task { @MainActor in
                    splashStatusMessage = status
                }
            }
            whisperLoaded = true
        } catch {
            print("Whisper preload failed: \(error.localizedDescription)")
        }

        switch (clipLoaded, whisperLoaded) {
        case (true, true):
            splashStatusMessage = "Finishing setup…"
        case (false, false):
            splashStatusMessage = "Continuing without model preload…"
        default:
            splashStatusMessage = "Continuing with partial model preload…"
        }

        await Task.yield()
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

            Tab("Activities", systemImage: "leaf.fill", value: AppTab.guidance.rawValue) {
                NavigationStack {
                    GuidanceView()
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
