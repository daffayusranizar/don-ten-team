//
//  StepThreeView.swift
//  team-10-c3
//
//  Created by Huy Tran on 04/06/26.
//

import SwiftUI

struct StepThreeView: View {
    @Binding var data: OnboardingData

    @State private var goToStepFour = false

    private var formCompleted: Bool {
        !data.childName.isEmpty &&
        data.childBirthdate != nil &&
        data.selectedAvatar != nil
    }

    var body: some View {
        VStack {
            VStack(alignment: .leading) {
                Text("Tell Us About Your Child")
                    .font(.system(size: 20, weight: .semibold)

                    )

                Text("We'll use this to personalise the guidance")
                    .fontWeight(.light)
                    .foregroundStyle(.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            // profile name selection
            VStack(alignment: .leading) {
                Text("Child's Name")
                    .font(.system(size: 18, weight: .medium))

                PrimaryTextField(
                    text: $data.childName,
                    placeholder: "Type name...",
                    size: .large,
                    systemImage: "person.crop.circle.fill"
                )
            }

            Spacer()

            // birthdate selection
            VStack(alignment: .leading) {
                Text("Birthdate")
                    .font(.system(size: 18, weight: .medium))

                PrimaryDateField(
                    date: $data.childBirthdate,
                    placeholder: "Insert Birthdate...",
                    size: .large,
                    systemImage: "calendar"
                )
            }

            Spacer()

            // gender selection
            HStack(spacing: 30) {
                RadioButton(
                    title: "Male",
                    isSelected: data.childIsMale,
                    action: { data.childIsMale = true }
                )

                RadioButton(
                    title: "Female",
                    isSelected: !data.childIsMale,
                    action: { data.childIsMale = false }
                )

                Spacer()
            }

            Spacer()

            // avatar selection
            VStack(alignment: .leading) {
                Text("Choose Avatar")
                    .font(.system(size: 18, weight: .medium))

                ScrollView(.horizontal) {
                    HStack(spacing: 20) {
                        ForEach(ChildAvatarImage.allCases) { avatar in
                            ChildAvatarOption(
                                avatar: avatar,
                                isSelected: data.selectedAvatar == avatar,
                                action: {
                                    data.selectedAvatar = avatar
                                }
                            )
                        }
                    }
                    .padding(.leading, 20)
                }
                .padding(.horizontal, -30)
            }
            .ignoresSafeArea()

            Spacer()

            // disclaimer
            HStack {
                Image(systemName: "info.circle")
                    .font(.system(size: 20))

                Spacer()

                Text("You can add more children or edit profiles later in settings")
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
                goToStepFour = true
            }
        }
        .foregroundStyle(.textPrimary)
        .padding(.horizontal, 30)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Step 3 of 5")
                    .foregroundStyle(.textSecondary)
                    .font(.system(size: 22, weight: .semibold))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $goToStepFour) {
            StepFourView(data: $data)
        }
    }
}
