//
//  ParentsAccessView.swift
//  team-10-c3
//
//  Created by Huy Tran on 01/06/26.
//

import SwiftUI

struct ParentsAccessView: View {
    @State var changePassword: Bool = false
    @State var setFaceID: Bool = false
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
                    .fill(.primarySoftPurple)
                    .opacity(0.2)
            )

            FamilyActivityPickerSection()
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(.primarySoftPurple)
                        .opacity(0.2)
                )

            if !familyControlsAuth.isAuthorized {
                PrimaryButton(
                    title: "Authorize Screen Time",
                    size: .medium,
                    systemImage: "hourglass",
                    action: {
                        Task {
                            try? await familyControlsAuth.requestAuthorization()
                        }
                    }
                )
            }

            Spacer()
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
        ParentsAccessView()
    }
}
