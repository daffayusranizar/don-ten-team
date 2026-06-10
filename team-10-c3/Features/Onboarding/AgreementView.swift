//
//  AgreementView.swift
//  team-10-c3
//
//  Created by Huy Tran on 04/06/26.
//

import SwiftUI

struct AgreementView: View {
    @Binding var data: OnboardingData
    @Environment(\.profileViewModel) private var profileViewModel
    @Environment(\.childRepository) private var childRepository

    @State private var agreedToTerms: Bool = false
    @State private var saveError: String?

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

            Text("By tapping \"I agree and Continue\", you confirm that you have read and agreed to our Terms of Use and Privacy Policy.")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.textSecondary)

            HStack(alignment: .center) {
                Button {
                    agreedToTerms.toggle()
                } label: {
                    Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                        .foregroundStyle(
                            agreedToTerms
                            ? .primaryMediumBlue
                            : .textSecondary
                        )
                }

                Text("I agree to the")

                NavigationLink("Terms of Use") {
                    TermsOfUse()
                }
                .foregroundStyle(.primarySoftPurple)
                .fontWeight(.semibold)

                Text("and")

                NavigationLink("Privacy Policy") {
                    PrivacyPolicyView()
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
                action: saveChildAndContinue
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
        .alert(
            "Could Not Save Child Profile",
            isPresented: Binding(
                get: { saveError != nil },
                set: {
                    if !$0 {
                        saveError = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                saveError = nil
            }
        } message: {
            Text(saveError ?? "")
        }
    }

    private func makeChild() -> Child? {
        guard
            let birthdate = data.childBirthdate,
            let avatar = data.selectedAvatar
        else {
            return nil
        }

        return Child(
            name: data.childName.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            dateOfBirth: birthdate,
            gender: data.childIsMale ? .boy : .girl,
            avatarAssetName: avatar.asset.rawValue
        )
    }

    private func saveChildAndContinue() {
        guard let child = makeChild() else {
            print("❌ makeChild returned nil")
            saveError = "Child information is incomplete."
            return
        }

        print("✅ Created child:")
        print("   name =", child.name)

        do {
            try childRepository.save(child)

            print("✅ Saved child to repository")

            let children = try childRepository.fetchAll()
            print("📦 Repository now contains \(children.count) children")
            children.forEach {
                print("   - \($0.name)")
            }
            
            print("AgreementView repo =", ObjectIdentifier(childRepository as AnyObject))
            profileViewModel.debugRepositoryAddress()

            profileViewModel.handleChildSaved(child)

            print("📋 ProfileViewModel children count =", profileViewModel.children.count)

            profileViewModel.selectedChild = child

            print("👤 Selected child =", profileViewModel.selectedChild?.name ?? "nil")

        } catch {
            print("❌ Save failed:", error)
            saveError = error.localizedDescription
        }
    }
}

#Preview {
    OnboardingView()
}
