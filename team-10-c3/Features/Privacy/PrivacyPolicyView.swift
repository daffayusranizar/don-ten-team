//
//  PrivacyPolicyView.swift
//  team-10-c3
//
//  Created by Huy Tran on 05/06/26.
//

import SwiftUI

struct Policy: Identifiable {
    let id: UUID = UUID()
}

struct PrivacyPolicyView: View {
    
    var body: some View {
        ScrollView {
            VStack {
                Introduction
                
                PolicyOne
            }
            .padding(.horizontal, 30)
        }
        .foregroundStyle(.textPrimary)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Privacy Policy")
                    .foregroundStyle(.textSecondary)
                    .font(.system(size: 22, weight: .semibold))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

private var Introduction: some View {
    VStack {
        // title
        VStack(alignment: .leading) {
            Text("Kiddly Privacy Policy")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Last updated: June 2026")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        
        // description
        Text("Kiddly is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our app and services. By using Kiddly, you agree to the collection and use of information in accordance with this Privacy Policy. If you do not agree with the terms of this Privacy Policy, please do not use the app.")
    }
}

private var PolicyOne: some View {
    VStack(alignment: .leading) {
        Text("1. Information We Collect")
        
        Text("From parents during onboarding:")
        Text("• Your notification preferences — used only to send check-in reminders and weekly suggestion alerts at times that fit your schedule")

        Text("From child profiles:")
        Text("• Your child's name, age, and gender — used only to personalise activity suggestions and content complexity")
        Text("• No photos, no location data, and no biometric data is collected from children at any point")

        Text("From sessions:")
        Text("• Screen time duration per app — which apps were used and for how long, collected via Apple's Screen Time API")
        Text("• If screen recording is enabled: on-device analysis of video titles and app names visible on screen during the session. This analysis happens entirely on your device using Apple's Vision framework. Raw screen content is never stored or transmitted.")
        Text("• Content category classification — Entertainment, Gaming, or Educational — derived from the on-device analysis above")
        Text("• Only classified metadata (not raw screen content) may be sent to our AI summary service if you have enabled that feature and consented to it during setup")

        Text("From the weekly check-in:")
        Text("• Whether you tried the weekly suggestion — Yes, or Not this time")
        Text("• How your child responded — selected from quick options or written as a personalised note")
        Text("• This data is stored locally on your device and is visible only to you")

        Text("From the history feature:")
        Text("• A record of your weekly check-in responses over time, organised by month")
        Text("• Stored locally on your device — not transmitted to our servers")

        Text("From the offline activity library:")
        Text("• Kiddly does not collect any data from your use of the offline activity library")
        Text("• The activity guides, instructions, and tips are static content stored within the app itself — no browsing history, reading time, or activity preferences are tracked or transmitted")
    }
}

//private func getPolicies () -> [String] {
//    return
//}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
