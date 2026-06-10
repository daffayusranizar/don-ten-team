//
//  PrivacyPolicyView.swift
//  team-10-c3
//
//  Created by Huy Tran on 05/06/26.
//

import SwiftUI

struct Policy: Identifiable {
    let id: UUID = UUID()
    let title: String
    let lines: [String]
}

struct PrivacyPolicyView: View {
    
    var body: some View {
        ScrollView {
            VStack(spacing: 15) {
                Introduction
                
                PolicyOne
                
                ForEach(getPolicies()) { policy in
                    buildPolicy(policy: policy)
                }
            }
            .padding(.horizontal, 30)
        }
        .foregroundStyle(.textPrimary)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Privacy Policy")
                    .font(.system(size: 28, weight: .semibold))
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
                .foregroundStyle(.textPrimary)
                .font(.system(size: 20, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Last updated: June 2026")
                .foregroundStyle(.textSecondary)
                .font(.system(size: 14, weight: .semibold))
                .italic(true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        
        // description
        Text("Kiddly is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our app and services. By using Kiddly, you agree to the collection and use of information in accordance with this Privacy Policy. If you do not agree with the terms of this Privacy Policy, please do not use the app."
        )
        .font(.system(size: 15, weight: .regular))
            .padding(.top, 10)
    }
}

private var PolicyOne: some View {
    VStack(alignment: .leading) {
        Text("1. Information We Collect")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.textPrimary)
        
        Text("From parents during onboarding:")
            .padding(.top, 10)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.textPrimary)
        Text("• Your notification preferences — used only to send check-in reminders and weekly suggestion alerts at times that fit your schedule\n")

        Text("From child profiles:")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.textPrimary)
        Text("• Your child's name, age, and gender — used only to personalise activity suggestions and content complexity")
        Text("• No photos, no location data, and no biometric data is collected from children at any point\n")

        Text("From sessions:")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.textPrimary)
        Text("• Screen time duration per app — which apps were used and for how long, collected via Apple's Screen Time API")
        Text("• If screen recording is enabled: on-device analysis of video titles and app names visible on screen during the session. This analysis happens entirely on your device using Apple's Vision framework. Raw screen content is never stored or transmitted.")
        Text("• Content category classification — Entertainment, Gaming, or Educational — derived from the on-device analysis above")
        Text("• Only classified metadata (not raw screen content) may be sent to our AI summary service if you have enabled that feature and consented to it during setup\n")

        Text("From the weekly check-in:")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.textPrimary)
        Text("• Whether you tried the weekly suggestion — Yes, or Not this time")
        Text("• How your child responded — selected from quick options or written as a personalised note")
        Text("• This data is stored locally on your device and is visible only to you\n")

        Text("From the history feature:")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.textPrimary)
        Text("• A record of your weekly check-in responses over time, organised by month")
        Text("• Stored locally on your device — not transmitted to our servers\n")

        Text("From the offline activity library:")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.textPrimary)
        Text("• Kiddly does not collect any data from your use of the offline activity library")
        Text("• The activity guides, instructions, and tips are static content stored within the app itself — no browsing history, reading time, or activity preferences are tracked or transmitted\n")
    }
    .foregroundStyle(.gray)
}

private func getPolicies() -> [Policy] {
    [
        Policy(
            title: "2. How We Use Your Information",
            lines: [
                "We use the information we collect for the following purposes only:",
                "• To generate your child's daily and weekly AI screen time summary",
                "• To produce the weekly suggestion personalised to your child's habits and your family's goals",
                "• To send you reminders and check-in notifications at times that fit your availability",
                "• To display your check-in history filtered by month in the History section of the app",
                "• To improve the accuracy of content category classification over time using only anonymised, aggregated patterns",
                "",
                "The offline activity library is provided entirely on-device as static content. It requires no internet connection and generates no user data.",
                "We will never use your information for advertising, profiling, or any purpose beyond what is described in this Privacy Policy."
            ]
        ),

        Policy(
            title: "3. What We Do Not Collect",
            lines: [
                "• We do not read, store, or transmit your child's messages, calls, or personal communications",
                "• We do not collect your personal screen activity — only sessions you explicitly start are analysed",
                "• We do not collect location data",
                "• We do not collect payment information directly — all purchases are handled by Apple",
                "• We do not use third-party advertising trackers",
                "• We do not sell your data to any third party",
                "• We do not collect any data from your use of the offline activity library"
            ]
        ),

        Policy(
            title: "4. AI-Generated Content and Data",
            lines: [
                "• Screen time duration and content category classifications are processed on your device first",
                "• Only classified metadata is sent to our AI summary service",
                "• Raw screen content, video titles, and app names are never sent externally",
                "• AI-generated summaries and suggestions are returned to your device and displayed in the app",
                "• We do not use your family's data to train AI models without your explicit consent"
            ]
        ),

        Policy(
            title: "5. Screen Recording and On-Device Processing",
            lines: [
                "• iOS will ask for your explicit permission before recording begins",
                "• The recording is processed entirely on your device using Apple's Vision and Core ML frameworks",
                "• No raw video or screen content is ever uploaded to our servers",
                "• Only classified output may be sent externally if AI summaries are enabled",
                "• If a phone call is received during a session, analysis is automatically paused"
            ]
        ),

        Policy(
            title: "6. Children's Privacy",
            lines: [
                "• No child under 13 creates an account or provides data directly",
                "• Children's data is used only to personalise the parent's guidance experience",
                "• We do not display advertising to children",
                "• Parents can delete their child's profile and associated data at any time"
            ]
        ),

        Policy(
            title: "7. Data Storage and Security",
            lines: [
                "• Session data, check-in responses, and history entries are stored locally on your device",
                "• We use industry-standard encryption for transmitted data",
                "• We do not retain session data longer than necessary to generate AI summaries"
            ]
        ),

        Policy(
            title: "8. Third-Party Services",
            lines: [
                "• Apple Screen Time API and ReplayKit for screen time tracking and session recording",
                "• AI summary services for generating summaries from classified metadata only",
                "• We do not use advertising networks, social media trackers, or invasive analytics services"
            ]
        ),

        Policy(
            title: "9. Your Rights",
            lines: [
                "• Access all data Kiddly holds about your family",
                "• Delete your account and all associated data",
                "• Delete your child's profile and associated data",
                "• Change or withdraw notification permissions at any time"
            ]
        ),

        Policy(
            title: "10. Data Retention",
            lines: [
                "• Account data is retained while your account remains active",
                "• Deleted account data is permanently removed within 30 days",
                "• Anonymous aggregated usage patterns may be retained indefinitely"
            ]
        ),

        Policy(
            title: "11. Changes to This Policy",
            lines: [
                "If we make significant changes to this Privacy Policy, we will notify you through the app before the changes take effect.",
                "Continued use of Kiddly after that date means you accept the updated policy."
            ]
        )
    ]
}

@ViewBuilder
private func buildPolicy (policy: Policy) -> some View {
    VStack(alignment: .leading) {
        Text(policy.title)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.textPrimary)
        
        VStack(alignment: .leading) {
            ForEach(policy.lines, id: \.self) { line in
                Text(line)
                    .foregroundStyle(.gray)
            }
        }
        .padding(.top, 10)
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
