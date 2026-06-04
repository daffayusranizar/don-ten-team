//
//  StepFourView.swift
//  team-10-c3
//
//  Created by Huy Tran on 04/06/26.
//

import SwiftUI

struct CheckBox: Identifiable {
    let id: UUID = UUID()
    let icon: String
    let title: String
    let description: String
    var isSelected: Bool
}

struct CheckBoxRow: View {
    let icon: String
    let title: String
    let description: String
    let isSelected: Bool
    
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)

                VStack(alignment: .leading) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                    Text(description)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                ZStack {
                    Circle()
                        .stroke(.textPrimary, lineWidth: 1.5)
                        .frame(width: 20, height: 20)

                    if isSelected {
                        ZStack {
                            Circle()
                                .fill(.textPrimary)
                                .frame(width: 20, height: 20)
                            Circle()
                                .fill(.white)
                                .frame(width: 8, height: 8)
                            Circle()
                                .fill(.primarySoftPurple.opacity(0.2))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }
        }
        .padding()
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(
                    isSelected
                    ? .primarySoftPurple.opacity(0.2)
                    : .white
                )
                .stroke(.primarySoftPurple, lineWidth: isSelected ? 2 : 0)
                .shadow(
                    color: .black.opacity(0.13),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
        .foregroundStyle(.textPrimary)
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

enum ParentGoal: String, CaseIterable, Identifiable {
    case talkMore
    case understandHabits
    case educationalContent
    case reduceScreenTime

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .talkMore:
            return "ellipsis.message"
        case .understandHabits:
            return "apps.iphone"
        case .educationalContent:
            return "books.vertical"
        case .reduceScreenTime:
            return "chart.line.downtrend.xyaxis"
        }
    }

    var title: String {
        switch self {
        case .talkMore:
            return "Talk more with my child"
        case .understandHabits:
            return "Understanding their screen habits"
        case .educationalContent:
            return "Encourage educational content"
        case .reduceScreenTime:
            return "Reduce screen time overall"
        }
    }

    var description: String {
        switch self {
        case .talkMore:
            return "Get conversation starters based on what they watch"
        case .understandHabits:
            return "Know what type of content they consume"
        case .educationalContent:
            return "Shift habits towards learning"
        case .reduceScreenTime:
            return "Help them connect with the real world"
        }
    }
}

struct StepFourView: View {
    @Binding var data: OnboardingData

    @State private var goToStepFive = false

    private var formCompleted: Bool {
        !data.selectedGoals.isEmpty
    }

    private func toggleGoal(_ goal: ParentGoal) {
        if data.selectedGoals.contains(goal) {
            data.selectedGoals.removeAll { $0 == goal }
            return
        }

        if data.selectedGoals.count < 2 {
            data.selectedGoals.append(goal)
        }
    }

    var body: some View {
        VStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("What matters most to you?")
                    .font(.system(size: 20, weight: .semibold))

                Text("Pick up to 2. This shapes the weekly suggestions we give you.")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 15) {
                ForEach(ParentGoal.allCases) { goal in
                    CheckBoxRow(
                        icon: goal.icon,
                        title: goal.title,
                        description: goal.description,
                        isSelected: data.selectedGoals.contains(goal)
                    ) {
                        toggleGoal(goal)
                    }
                }
            }

            Spacer()

            PrimaryButton(
                title: "Continue",
                size: .large,
                systemImage: nil,
                isDisabled: !formCompleted
            ) {
                goToStepFive = true
            }
        }
        .foregroundStyle(.textPrimary)
        .padding(.horizontal, 30)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Step 4 of 5")
                    .foregroundStyle(.textSecondary)
                    .font(.system(size: 22, weight: .semibold))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $goToStepFive) {
            StepFiveView(data: $data)
        }
    }
}
