//
//  StepOneView.swift
//  team-10-c3
//
//  Created by Huy Tran on 05/06/26.
//

import SwiftUI

struct StepOneView: View {
    @Binding var data: OnboardingData

    @State private var goToPinSetup = false

    private var formCompleted: Bool {
        !data.parentName.isEmpty &&
        data.parentBirthdate != nil
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
                    text: $data.parentName,
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
                    date: $data.parentBirthdate,
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
                goToPinSetup = true
            }
        }
        .foregroundStyle(.textPrimary)
        .padding(.horizontal, 30)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Step 1 of 6")
                    .foregroundStyle(.textSecondary)
                    .font(.system(size: 22, weight: .semibold))
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $goToPinSetup) {
            ParentPinSetupView(data: $data)
        }
        .dismissKeyboardOnTap()
    }
}

#Preview {
    NavigationStack {
        OnboardingView()
    }
}
