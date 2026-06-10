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

    var body: some View {
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
    RootView()
}
