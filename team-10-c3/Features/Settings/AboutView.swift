//
//  AboutView.swift
//  team-10-c3
//
//  Created by Huy Tran on 01/06/26.
//

import SwiftUI

struct AboutView: View {
    @State var viewPrivacyPolicy: Bool = false
    @State var viewTerms: Bool = false
    
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
                
                Text("About")
                    .font(.system(size: 25, weight: .bold))
            }
            
            VStack(alignment: .leading) {
                NavLink(
                    icon: "hand.raised.fill",
                    title: "Privacy policy",
                    changePage: $viewPrivacyPolicy
                ) {
                    ChangePasswordView()
                }
                
                Divider()
                
                NavLink(
                    icon: "text.document.fill",
                    title: "Terms of Use",
                    changePage: $viewTerms
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
        AboutView()
    }
}
