//
//  RootView.swift
//  team-10-c3
//
//  Created by Huy Tran on 26/05/26.
//
// [P1] Routes: Onboarding ↔️ Dashboard

import SwiftUI

struct RootView: View {
    @Environment(\.sessionCoordinator) private var sessionCoordinator

    var body: some View {
        @Bindable var sessionCoordinator = sessionCoordinator

        NavigationStack {
            DashboardView()
        }
    }
}

#Preview {
    RootView()
}
