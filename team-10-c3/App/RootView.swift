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
        if PreviewRuntime.isActive {
            splashStatusMessage = "Loading preview…"
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation { showSplashScreen = false }
            return
        }

        splashStatusMessage = "Loading screen analysis model…"
        var clipLoaded = false
        var whisperLoaded = false

        await withTaskGroup(of: SplashModelLoadResult.self) { group in
            group.addTask {
                do {
                    try await MobileCLIPModelLoader.preload()
                    return .clipSucceeded
                } catch {
                    print("MobileCLIP preload failed: \(error.localizedDescription)")
                    return .clipFailed
                }
            }
            group.addTask {
                do {
                    try await WhisperModelLoader.preload()
                    return .whisperSucceeded
                } catch {
                    print("Whisper preload failed: \(error.localizedDescription)")
                    return .whisperFailed
                }
            }

            var clipFinished = false
            var whisperFinished = false

            for await result in group {
                switch result {
                case .clipSucceeded:
                    clipLoaded = true
                    clipFinished = true
                case .clipFailed:
                    clipFinished = true
                case .whisperSucceeded:
                    whisperLoaded = true
                    whisperFinished = true
                case .whisperFailed:
                    whisperFinished = true
                }

                if clipFinished && !whisperFinished {
                    splashStatusMessage = "Loading speech recognition…"
                } else if whisperFinished && !clipFinished {
                    splashStatusMessage = "Loading screen analysis model…"
                }
            }
        }

        switch (clipLoaded, whisperLoaded) {
        case (true, true):
            splashStatusMessage = "Finishing setup…"
        case (false, false):
            splashStatusMessage = "Continuing without model preload…"
        default:
            splashStatusMessage = "Continuing with partial model preload…"
        }

        try? await Task.sleep(for: .milliseconds(350))

        withAnimation {
            showSplashScreen = false
        }
    }

    private enum SplashModelLoadResult {
        case clipSucceeded
        case clipFailed
        case whisperSucceeded
        case whisperFailed
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
