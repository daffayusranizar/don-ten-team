//
//  ApprovedAppsView.swift
//  team-10-c3
//
//  Created by Huy Tran on 29/05/26.
//

import SwiftUI

struct ApprovedAppsView: View {
    @Environment(\.profileViewModel) private var profileViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            toolbar

            if let child = profileViewModel.selectedChild {
                Text("Choose which apps \(child.name) can use during sessions. App selection will be available when Screen Time controls are connected.")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            } else {
                Text("Select a child on the dashboard to manage approved apps.")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }

            approvedAppsEmptyState

            Spacer()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .padding(.horizontal, 30)
        .padding(.vertical)
        .foregroundStyle(.textPrimary)
    }

    private var toolbar: some View {
        ZStack {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .padding()
                        .background(
                            Circle()
                                .fill(.uiSurface)
                        )
                }

                Spacer()
            }

            Text("Approved Apps")
                .font(.system(size: 25, weight: .bold))
        }
    }

    private var approvedAppsEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "apps.iphone")
                .font(.system(size: 40))
                .foregroundStyle(.primaryMediumBlue)

            Text("No approved apps configured")
                .font(.system(size: 18, weight: .semibold))

            Text("Family Controls app picking is not set up yet. Until then, all monitored device usage is reported without per-app allowlists.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(.primaryMediumBlue)
                .opacity(0.2)
        )
    }
}

#Preview {
    NavigationStack {
        ApprovedAppsView()
            .environment(\.profileViewModel, ProfileViewModel(childRepository: InMemoryChildRepository()))
    }
}
