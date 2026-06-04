//
//  StepFiveView.swift
//  team-10-c3
//
//  Created by Huy Tran on 04/06/26.
//
import SwiftUI

struct StepFiveView: View {
    @Binding var data: OnboardingData
    
    @State var goToReviewPage: Bool = false
    
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
                
                Image(systemName: "bell")
                    .foregroundStyle(.white)
                    .font(.system(size: 30))
            }
            
            VStack(spacing: 5) {
                Text("Get Weekly \n Reminders!")
                    .font(.system(size: 20, weight: .semibold))
                Text("Choose which reminders you'd like. You can change these anytime in Settings.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // notification settings
            VStack(alignment: .leading) {
                Text("Notifications")
                
                NotificationToggle(
                    icon: "bell.circle.fill",
                    title: "Weekly Suggestion Reminder",
                    isOn: $data.weeklySuggestions
                )
                .font(.system(size: 15, weight: .regular))
                
                Divider()
                
                NotificationToggle(
                    icon: "calendar.circle.fill",
                    title: "Weekly Check-In",
                    isOn: $data.weeklyCheckIns
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(.primaryMediumBlue)
                    .opacity(0.2)
            )
            
            Spacer()
            
            // forward buttons
            VStack(spacing: 15) {
                PrimaryButton(
                    title: "Continue",
                    action: { goToReviewPage = true }
                )
                
                Button {
                    goToReviewPage = true
                } label : {
                    Text("Set Up Later")
                        .foregroundStyle(.textSecondary)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
        }
        .foregroundStyle(.textPrimary)
        .padding(.horizontal, 30)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Step 5 of 5")
                    .foregroundStyle(.textSecondary)
                    .font(.system(size: 22, weight: .semibold))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $goToReviewPage) {
            ReviewView(data: $data)
        }
    }
}

#Preview {
    NavigationStack {
        OnboardingView()
    }
}
