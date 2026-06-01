//
//  SettingsView.swift
//  team-10-c3
//
//  Created by Huy Tran on 29/05/26.
//

import SwiftUI

struct SettingsView: View {
    @State var weeklyReminder: Bool = false
    @State var weeklyCheckIn: Bool = false
    @State var showApprovedApps: Bool = false
    @State var showParentsAccess: Bool = false
    @State var showAboutPage: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 18) {
            // tool bar
            HStack {
                // back button
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
                Text("Settings")
                    .font(.system(size: 25, weight: .bold))
                Spacer()
                
                // additional button?
                Button {
                    
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20, weight: .semibold))
                        .padding()
                        .background(
                            Circle()
                                .fill(.uiSurface)
                        )
                }
            }
            
            // profile avatar
            ZStack {
                Circle()
                    .fill(.decorativeLavender)
                    .opacity(0.3)
                
                Text("Avatar")
                    .font(.system(size: 20, weight: .bold))
            }
            .frame(height: 150)
            
            // profile details
            VStack {
                Text("Raka")
                    .font(.system(size: 30, weight: .medium))
                Text("Age 8 | Male")
                    .font(.system(size: 20, weight: .medium))
            }
            
            // screen time settings
            VStack(alignment: .leading) {
                Text("Screen Time")
                    .font(.system(size: 20, weight: .semibold))
                
                // approved apps
                NavLink(icon: "checkmark.circle.fill", title: "Approved Apps", changePage: $showApprovedApps) {
                    ApprovedAppsView()
                }
                
                Divider()
                
                // parents access
                NavLink(icon: "lock.circle.fill", title: "Parents Access", changePage: $showParentsAccess) {
                    ParentsAccessView()
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(.primarySoftPurple)
                    .opacity(0.2)
            )
            
            // notification settings
            VStack(alignment: .leading) {
                Text("Notifications")
                    .font(.system(size: 20, weight: .semibold))
                
                // weekly suggestion reminder
                NotificationToggle(icon: "bell.circle.fill", title: "Weekly Suggestion Reminder", isOn: $weeklyReminder)

                Divider()
                
                // weekly check-in
                NotificationToggle(icon: "calendar.circle.fill", title: "Weekly Check-In", isOn: $weeklyCheckIn)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(.primarySoftPurple)
                    .opacity(0.2)
            )
            
            // more information
            VStack(alignment: .leading) {
                Text("More Information")
                    .font(.system(size: 20, weight: .semibold))
                
                // about
                NavLink(icon: "i.circle.fill", title: "About", changePage: $showAboutPage) {
                    AboutView()
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(.primarySoftPurple)
                    .opacity(0.2)
            )
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .padding(.horizontal, 30)
        .padding(.vertical)
        .foregroundStyle(.textPrimary)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
