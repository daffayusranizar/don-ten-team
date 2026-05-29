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
            // ! can maybe make this as component
            VStack(alignment: .leading) {
                Text("Screen Time")
                    .font(.system(size: 20, weight: .semibold))
                
                // approved apps
                HStack {
                    Button {
                        showApprovedApps = true
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 25, weight: .semibold))
                                .foregroundStyle(.textPrimary)
                            Text("Approved Apps")

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 20, weight: .regular))
                                .foregroundStyle(.textPrimary)
                        }
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                
                Divider()
                
                // parents access
                HStack {
                    Button {
  
                    } label: {
                        HStack {
                            Image(systemName: "lock.circle.fill")
                                .font(.system(size: 25, weight: .semibold))
                                .foregroundStyle(.textPrimary)
                            Text("Parents Access")

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 20, weight: .regular))
                                .foregroundStyle(.textPrimary)
                        }
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
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
                notification(icon: "bell.circle.fill", title: "Weekly Suggestion Reminder", isOn: $weeklyReminder)

                Divider()
                
                // weekly check-in
                notification(icon: "calendar.circle.fill", title: "Weekly Check-In", isOn: $weeklyCheckIn)
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
                HStack {
                    Button {
  
                    } label: {
                        HStack {
                            Image(systemName: "i.circle.fill")
                                .font(.system(size: 25, weight: .semibold))
                                .foregroundStyle(.textPrimary)
                            Text("About")

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 20, weight: .regular))
                                .foregroundStyle(.textPrimary)
                        }
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
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
        .navigationDestination(isPresented: $showApprovedApps) {
            ApprovedAppsView()
        }
    }
}

private func notification (icon: String, title: String, isOn: Binding<Bool>) -> some View {
    HStack {
        Image(systemName: icon)
            .font(.system(size: 25, weight: .semibold))
            .foregroundStyle(.textPrimary)
        Text(title)

        Spacer()

        Toggle("", isOn: isOn)
    }
    .padding(.vertical, 5)
    .frame(maxWidth: .infinity)
    .contentShape(Rectangle())
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
