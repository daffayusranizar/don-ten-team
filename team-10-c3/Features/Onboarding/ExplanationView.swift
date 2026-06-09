//
//  ExplanationView.swift
//  team-10-c3
//
//  Created by Huy Tran on 04/06/26.
//

import SwiftUI

struct step: Identifiable {
    let id = UUID()
    let title: String
    let description: String
}

struct ExplanationView: View {
    @Binding var data: OnboardingData

    @State private var goToAgreementsPage: Bool = false
    
    private let steps: [step] = [
        step(
            title: "Start a Session",
            description: "Before handing your phone to your child, start a session. Set the time limit and choose whether to enable screen recording."
        ),
        step(
            title: "We Analyse Content On-Device",
            description: "Kiddly analyses what your child watches: Entertainment, Gaming, or Educational. This happens on your phone. Raw content is never stored or sent."
        ),
        step(
            title: "You get an AI Summary",
            description: "Every day and week, Kiddly turns screen time into a short summary, just what matters."
        ),
        step(
            title: "One Suggestion, Once a Week",
            description: "Based on what your child watches, you get one activity suggestion to try together. Try it or skip, no pressure."
        ),
        step(
            title: "Track What Happens Next",
            description: "The morning after you commit to a suggestion, Kiddly sends you a short check-in. Did you try it? How did your child respond? You have 7 days to fill it in — after that it disappears on its own. Your answers are saved to your history so you can look back on what worked for your family over time."
        )
    ]
    
    var body: some View {
        ScrollView {
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
                    
                    Image(systemName: "pencil.line")
                        .foregroundStyle(.white)
                        .font(.system(size: 30))
                }
                
                VStack(spacing: 5) {
                    Text("How Kiddly Works")
                        .font(.system(size: 20, weight: .semibold))
                    Text("A quick overview before you get started.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.textSecondary)
                }
                .multilineTextAlignment(.center)
                
                // steps
                VStack() {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, row in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("\(index + 1)")
                                    .padding()
                                    .foregroundStyle(.white)
                                    .background(
                                        Circle()
                                            .fill(.primaryMediumBlue)
                                    )

                                Text(row.title)
                                    .font(.system(size: 16, weight: .semibold))

                                Spacer()
                            }

                            Text(row.description)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Spacer()

                            if (index < 4) {
                                Divider()
                            }
                        }
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
                    action: { goToAgreementsPage = true }
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
            .navigationDestination(isPresented: $goToAgreementsPage) {
                AgreementView(data: $data)
            }
        }
    }
}

#Preview {
    OnboardingView()
}
