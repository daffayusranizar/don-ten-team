//
//  StepTwoView.swift
//  team-10-c3
//
//  Created by Huy Tran on 05/06/26.
//

import SwiftUI

enum FamilySituation: String, CaseIterable, Identifiable {
    case twoParents
    case singleParent
    case oneWorking
    case extended

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .twoParents:
            return "ellipsis.message"
        case .singleParent:
            return "apps.iphone"
        case .oneWorking:
            return "books.vertical"
        case .extended:
            return "chart.line.downtrend.xyaxis"
        }
    }

    var title: String {
        switch self {
        case .twoParents:
            return "Two working parents"
        case .singleParent:
            return "Single parent"
        case .oneWorking:
            return "One parent works, one at home"
        case .extended:
            return "Extended / Multi-generational"
        }
    }

    var description: String {
        switch self {
        case .twoParents:
            return "Both parents work, limited time at home"
        case .singleParent:
            return "Managing on my own"
        case .oneWorking:
            return "More available during the day"
        case .extended:
            return "More available during the day"
        }
    }
}

struct StepTwoView: View {
    @Binding var data: OnboardingData

    @State private var goToStepThree = false

    private var formCompleted: Bool {
        data.familySituation != nil
    }
    
    private func handleToggle (_ situation: FamilySituation) {
        if (situation == data.familySituation) {
            data.familySituation = nil
        } else {
            data.familySituation = situation
        }
    }

    var body: some View {
        VStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("What's your family situation?")
                    .font(.system(size: 20, weight: .semibold))

                Text("This helps us tailor the parental suggestion.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 15) {
                ForEach(FamilySituation.allCases) { situation in
                    CheckBoxRow(
                        icon: situation.icon,
                        title: situation.title,
                        description: situation.description,
                        isSelected: data.familySituation == situation
                    ) {
                        handleToggle(situation)
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
                goToStepThree = true
            }
        }
        .foregroundStyle(.textPrimary)
        .padding(.horizontal, 30)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(OnboardingProgress.title(step: 2))
                    .foregroundStyle(.textSecondary)
                    .font(.system(size: 22, weight: .semibold))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $goToStepThree) {
            StepThreeView(data: $data)
        }
    }
}

#Preview {
    NavigationStack {
        OnboardingView()
    }
}
