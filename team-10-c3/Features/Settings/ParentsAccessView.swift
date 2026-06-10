//
//  ParentsAccessView.swift
//  team-10-c3
//
//  Created by Huy Tran on 01/06/26.
//

import SwiftUI
import UIKit

struct ParentsAccessView: View {
    @State var changePassword: Bool = false
    @State var setFaceID: Bool = false
    #if DEBUG
    @State var showScreenTimeDebug: Bool = false
    #endif
    @State private var showScreenTimeAuthAlert = false
    @State private var showDebugLogCopied = false
    @Environment(\.familyControlsAuth) private var familyControlsAuth

    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 18) {
            // tool bar
            ZStack {
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
                }
                
                Text("Parent's Access")
                    .font(.system(size: 25, weight: .bold))
            }
            
            VStack(alignment: .leading) {
                NavLink(
                    icon: "person.badge.key.fill",
                    title: "Change Password",
                    changePage: $changePassword
                ) {
                    ChangePasswordView()
                }
                
                Divider()
                
                NavLink(
                    icon: "faceid",
                    title: "Set Face ID",
                    changePage: $setFaceID
                ) {
                    ChangePasswordView()
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(.primaryMediumBlue)
                    .opacity(0.2)
            )

            FamilyActivityPickerSection(onRequireScreenTimeAuth: { showScreenTimeAuthAlert = true })
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(.primaryMediumBlue)
                        .opacity(0.2)
                )

            if familyControlsAuth.needsPermissionPrompt {
                ScreenTimePermissionBanner(
                    gaps: familyControlsAuth.missingPermissions,
                    statusDescription: familyControlsAuth.authorizationStatusDescription,
                    onEnable: { showScreenTimeAuthAlert = true }
                )
            } else {
                Label("Screen Time ready", systemImage: "checkmark.shield.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.green)
                Text("Status: \(familyControlsAuth.authorizationStatusDescription)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(signedEntitlementStatusLine)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            #if DEBUG
            NavLink(
                icon: "ladybug.fill",
                title: "Screen Time Debugger",
                changePage: $showScreenTimeDebug
            ) {
                ScreenTimeDebugView()
            }
            #endif

            Button {
                UIPasteboard.general.string = DebugSessionLog.readAppGroupContents()
                showDebugLogCopied = true
            } label: {
                Label("Copy auth debug log", systemImage: "doc.on.doc")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .padding(.horizontal, 30)
        .padding(.vertical)
        .foregroundStyle(.textPrimary)
        .onAppear {
            familyControlsAuth.refreshAuthorizationStatus()
        }
        .screenTimeAuthorizationAlert(isPresented: $showScreenTimeAuthAlert)
        .alert("Debug log copied", isPresented: $showDebugLogCopied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Paste the log into Cursor chat so we can compare TestFlight vs Xcode builds.")
        }
    }

    private var signedEntitlementStatusLine: String {
        let channel = DebugSessionLog.buildChannel.rawValue
        if familyControlsAuth.isAuthorized {
            return "Build: \(channel) · Screen Time: authorized"
        }
        return "Build: \(channel) · Screen Time: not authorized yet"
    }
}

#Preview {
    NavigationStack {
        ParentsAccessView()
    }
}
