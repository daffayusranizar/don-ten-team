//
//  StepOneView.swift
//  team-10-c3
//
//  Created by Huy Tran on 05/06/26.
//

import SwiftUI

struct StepOneView: View {
    @Binding var data: OnboardingData

    @State private var parentName = ""
    @State private var parentBirthdate: Date?
    @State private var goToStepTwo = false

    private var formCompleted: Bool {
        !parentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        parentBirthdate != nil
    }

    var body: some View {
        VStack(spacing: 15) {
            VStack(alignment: .leading) {
                Text("What should we call you?")
                    .font(.system(size: 20, weight: .semibold)

                    )

                Text("The app will use this when talking to you.")
                    .foregroundStyle(.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // profile name selection
            VStack(alignment: .leading) {
                Text("Your Name")
                    .font(.system(size: 18, weight: .medium))

                PrimaryTextField(
                    text: $parentName,
                    placeholder: "e.g Sarah",
                    size: .large,
                    systemImage: "person.crop.circle.fill"
                )
            }

            // birthdate selection
            VStack(alignment: .leading) {
                Text("How old are you?")
                    .font(.system(size: 18, weight: .medium))

                PrimaryDateField(
                    date: $parentBirthdate,
                    placeholder: "Insert Birthdate...",
                    size: .large,
                    systemImage: "calendar"
                )
            }

            // disclaimer
            HStack {
                Image(systemName: "info.circle")
                    .font(.system(size: 20))

                Spacer()

                Text("Your age helps us personalise the weekly suggestions.")
                    .font(.system(size: 14))
            }
            .padding()
            .foregroundStyle(.textSecondary)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(.uiSurface)
            )

            Spacer()

            PrimaryButton(
                title: "Continue",
                size: .large,
                systemImage: nil,
                isDisabled: !formCompleted
            ) {
                data.parentName = parentName.trimmingCharacters(in: .whitespacesAndNewlines)
                data.parentBirthdate = parentBirthdate
                goToStepTwo = true
            }
        }
        .foregroundStyle(.textPrimary)
        .padding(.horizontal, 30)
        .onAppear {
            if parentName.isEmpty {
                parentName = data.parentName
            }
            if parentBirthdate == nil {
                parentBirthdate = data.parentBirthdate
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(OnboardingProgress.title(step: 1))
                    .foregroundStyle(.textSecondary)
                    .font(.system(size: 22, weight: .semibold))
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $goToStepTwo) {
            StepTwoView(data: $data)
        }
        .dismissKeyboardOnTap()
    }
}

#Preview {
    NavigationStack {
        OnboardingView()
    }
}
