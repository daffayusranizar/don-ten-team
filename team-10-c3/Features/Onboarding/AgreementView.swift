//
//  AgreementView.swift
//  team-10-c3
//
//  Created by Huy Tran on 04/06/26.
//

import SwiftUI

struct AgreementView: View {
    //@Binding var data: OnboardingData

    @State private var agreedToTerms: Bool = false
    @State private var goToAgreementsPage: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            // bell icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.primaryDarkBlue, .blue],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "lock")
                    .foregroundStyle(.white)
                    .font(.system(size: 30))
            }
            
            VStack(spacing: 5) {
                Text("Before You Begin")
                    .font(.system(size: 20, weight: .semibold))
                Text("Kiddly collects screen time data with your permission and analyses your child's session content to generate summaries and suggestions. Here is what you are agreeing to:")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.textSecondary)
            }
            .multilineTextAlignment(.center)
            
            // agreements
            VStack(alignment: .leading, spacing: 10) {
                Text("• Kiddly will track which apps your child uses during sessions you start")
                Divider()
                
                Text("• If screen recording is enabled, Kiddly will only analyse the content type on your device, raw content is never stored or sent externally")
                Divider()
                
                Text("• Your data is never sold or shared to advertisers")
                Divider()
                
                Text("• You can delete your data at any time from Settings")
            }
            .font(.system(size: 15, weight: .regular))
            .padding()
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(.primaryMediumBlue)
                    .opacity(0.2)
            )
            
            // terms and conditions and privacy policy agreement
            Text("By tapping \"I agree and Continue\", you confirm that you have read and agreed to our Terms of Use and Privacy Policy.")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.textSecondary)
            HStack(alignment: .center) {
                Button {
                    agreedToTerms.toggle()
                } label: {
                    Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                    .foregroundStyle(agreedToTerms ? .primaryMediumBlue : .textSecondary)
                }
                
                Text("I agree to the")
                
                NavigationLink("Terms of Use") {
                    // temp, link to page
                }
                .foregroundStyle(.primarySoftPurple)
                .fontWeight(.semibold)
                
                Text("and")
                
                NavigationLink("Privacy Policy") {
                    // temp, link to page
                }
                .foregroundStyle(.primarySoftPurple)
                .fontWeight(.semibold)
            }
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(.textSecondary)
            .frame(maxWidth: .infinity)
            
            Spacer()
            
            PrimaryButton(
                title: "I Agree and Continue",
                isDisabled: !agreedToTerms,
                action: { goToAgreementsPage = true }
            )
        }
        .animation(.easeInOut(duration: 0.2), value: agreedToTerms)
        .foregroundStyle(.textPrimary)
        .padding(.horizontal, 30)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Review")
                    .foregroundStyle(.textSecondary)
                    .font(.system(size: 22, weight: .semibold))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $goToAgreementsPage) {
            AgreementView()
        }
    }
}

#Preview {
    AgreementView()
}
