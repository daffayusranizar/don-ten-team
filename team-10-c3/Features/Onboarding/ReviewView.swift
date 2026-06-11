//
//  ReviewView.swift
//  team-10-c3
//
//  Created by Huy Tran on 04/06/26.
//

import SwiftUI

extension Date {
    func age(asOf date: Date = Date()) -> Int {
        Calendar.current.dateComponents([.year], from: self, to: date).year ?? 0
    }
}

struct ReviewView: View {
    @Binding var data: OnboardingData

    @State var goToExplanationPage: Bool = false
    
    private var age: Int? {
        data.childBirthdate?.age()
    }

    private var allowedAppsSummary: String {
        let count = FamilyActivitySelectionStore.allowedAppCount
        if count == 0 { return "Not set up yet" }
        return "\(count) app\(count == 1 ? "" : "s") selected"
    }
    
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
                
                Image(systemName: "heart")
                    .foregroundStyle(.white)
                    .font(.system(size: 30))
            }
            
            VStack(spacing: 5) {
                Text("You're Ready,\n \(data.parentName)")
                    .font(.system(size: 20, weight: .semibold))
                Text("Here's what we've set up for you and \(data.childName)")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.textSecondary)
            }
            .multilineTextAlignment(.center)
            
            // final view of data
            VStack(alignment: .leading) {
                HStack {
                    Text("Family Type")
                        .font(.system(size: 15, weight: .bold))
                    
                    Spacer()
                    
                    Text(data.familySituation?.title ?? "")
                }
                
                Divider()
                
                HStack {
                    Text("Child")
                        .font(.system(size: 15, weight: .bold))
                    
                    Spacer()
                    
                    Text("\(data.childName) | Age \(age ?? 0) | \(data.childIsMale ? "Male" : "Female")")
                }
                
                Divider()
                
                HStack {
                    Text("Your Goals")
                        .font(.system(size: 15, weight: .bold))
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        ForEach(data.selectedGoals) { goal in
                            Text("\(goal.description),")
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                Divider()

                HStack {
                    Text("Allowed Apps")
                        .font(.system(size: 15, weight: .bold))

                    Spacer()

                    Text(allowedAppsSummary)
                }
            }
            .padding()
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(.primaryMediumBlue)
                    .opacity(0.2)
            )
            
            Spacer()
            
            PrimaryButton(
                title: "Continue",
                action: { goToExplanationPage = true }
            )
        }
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
        .navigationDestination(isPresented: $goToExplanationPage) {
            ExplanationView(data: $data)
        }
    }
}

#Preview {
    NavigationStack {
        OnboardingView()
    }
}
