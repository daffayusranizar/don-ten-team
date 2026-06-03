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
    case guidance
    case session
}


struct RootView: View {
    @SceneStorage("selectedTab") private var selectedTab = AppTab.dashboard.rawValue

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                Tab("Dashboard", systemImage: "house.fill", value: AppTab.dashboard.rawValue) {
                    DashboardView()
                }

                Tab("Guidance", systemImage: "book.fill", value: AppTab.guidance.rawValue) {
//                    GuidanceView()
                }
                Tab("Session", systemImage: "record.circle", value: AppTab.session.rawValue, role: .search) {
                    SessionSetupView()
                }
            }
            .tabViewStyle(.sidebarAdaptable)
        }
    }
}


#Preview {
    RootView()
}
