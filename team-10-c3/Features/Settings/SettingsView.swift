//
//  SettingsView.swift
//  team-10-c3
//
//  Created by Huy Tran on 29/05/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.profileViewModel) private var profileViewModel
    @State var weeklyReminder: Bool = false
    @State var weeklyCheckIn: Bool = false
    @State var showApprovedApps: Bool = false
    @State var showParentsAccess: Bool = false
    @State var showAddChild: Bool = false
    @State var showAboutPage: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                selectedChildSection

                screenTimeSection

                notificationSection

                moreInformationSection
            }
            .padding(.horizontal, 30)
            .padding(.vertical)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)

        .foregroundStyle(.textPrimary)
        .onAppear {
            profileViewModel.loadChildren()
        }
        .childProfileFormSheet(isPresented: $showAddChild) { child in
            profileViewModel.handleChildSaved(child)
        }
    }

    @ViewBuilder
    private var selectedChildSection: some View {
        if let child = profileViewModel.selectedChild {
            ProfileAvatarView(child: child, size: 120)

            VStack(spacing: 8) {
                Text(child.name)
                    .font(.system(size: 30, weight: .medium))

                Text("Age \(child.currentAge) | \(genderLabel(for: child))")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 48))
                    .foregroundStyle(.primaryMediumBlue)

                Text("No child selected")
                    .font(.system(size: 22, weight: .semibold))

                Text("Add a child profile to get started.")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                PrimaryButton(
                    title: "Add Child",
                    size: .medium,
                    systemImage: "plus",
                    action: { showAddChild = true }
                )
            }
            .padding(.vertical, 12)
        }
    }

    private var screenTimeSection: some View {
        VStack(alignment: .leading) {
            Text("Screen Time")
                .font(.system(size: 20, weight: .semibold))

            NavLink(icon: "checkmark.circle.fill", title: "Approved Apps", changePage: $showApprovedApps) {
                ApprovedAppsView()
            }

            Divider()

            NavLink(icon: "lock.circle.fill", title: "Parents Access", changePage: $showParentsAccess) {
                ParentsAccessView()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(.primaryMediumBlue)
                .opacity(0.2)
        )
    }

    private var notificationSection: some View {
        VStack(alignment: .leading) {
            Text("Notifications")
                .font(.system(size: 20, weight: .semibold))

            NotificationToggle(icon: "bell.circle.fill", title: "Weekly Suggestion Reminder", isOn: $weeklyReminder)

            Divider()

            NotificationToggle(icon: "calendar.circle.fill", title: "Weekly Check-In", isOn: $weeklyCheckIn)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(.primaryMediumBlue)
                .opacity(0.2)
        )
    }

    private var moreInformationSection: some View {
        VStack(alignment: .leading) {
            Text("More Information")
                .font(.system(size: 20, weight: .semibold))

            NavLink(icon: "i.circle.fill", title: "About", changePage: $showAboutPage) {
                AboutView()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(.primaryMediumBlue)
                .opacity(0.2)
        )
    }

    private func genderLabel(for child: Child) -> String {
        switch child.gender {
        case .boy: return "Male"
        case .girl: return "Female"
        case .preferNotToSay: return "Prefer not to say"
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(\.profileViewModel, ProfileViewModel(childRepository: InMemoryChildRepository()))
    }
}
