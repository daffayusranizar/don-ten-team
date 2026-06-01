//
//  ApprovedAppsView.swift
//  team-10-c3
//
//  Created by Huy Tran on 29/05/26.
//

import SwiftUI

struct ApprovedAppsView: View {
    @State var youtubeAllowed: Bool = false
    @State var tiktokAllowed: Bool = false
    @State var instagramAllowed: Bool = false
    
    @State var mobileLegendsAllowed: Bool = false
    @State var candyCrushAllowed: Bool = false
    @State var pubgAllowed: Bool = false
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
                
                Text("Approved Apps")
                    .font(.system(size: 25, weight: .bold))
            }
            
            Text("Only the approved apps will be accessible for Raka to use.")
            
            VStack(alignment: .leading) {
                Text("Entertainment")
                    .font(.system(size: 20, weight: .semibold))
                
                NotificationToggle(icon: "bell.circle.fill", title: "YouTube", isOn: $youtubeAllowed)
                
                Divider()
                
                NotificationToggle(icon: "bell.circle.fill", title: "TikTok", isOn: $tiktokAllowed)
                
                Divider()
                
                NotificationToggle(icon: "bell.circle.fill", title: "Instagram", isOn: $instagramAllowed)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(.primarySoftPurple)
                    .opacity(0.2)
            )
            
            VStack(alignment: .leading) {
                Text("Games")
                    .font(.system(size: 20, weight: .semibold))
                
                NotificationToggle(icon: "bell.circle.fill", title: "Mobile Legends", isOn: $mobileLegendsAllowed)
            
                Divider()
                
                NotificationToggle(icon: "bell.circle.fill", title: "Candy Crush", isOn: $candyCrushAllowed)
                
                Divider()
                
                NotificationToggle(icon: "bell.circle.fill", title: "PUBG Mobile", isOn: $pubgAllowed)
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
        ApprovedAppsView()
    }
}
