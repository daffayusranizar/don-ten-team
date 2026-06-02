//
//  ProfileFormView.swift
//  team-10-c3
//
//  Created by Huy Tran on 26/05/26.
//
// [P1] Create / edit child profile

import SwiftUI

// TODO: put this in design system
struct RadioButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(.primaryMediumBlue, lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(.primaryMediumBlue)
                            .frame(width: 22, height: 22)
                    }
                }

                Text(title)
                    .foregroundColor(.textPrimary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

struct ProfileFormView: View {
    @Environment(\.childRepository) private var childRepository
    private let onSaveSuccess: ((Child) -> Void)?

    init(onSaveSuccess: ((Child) -> Void)? = nil) {
        self.onSaveSuccess = onSaveSuccess
    }

    var body: some View {
        ProfileFormScreen(
            childRepository: childRepository,
            onSaveSuccess: onSaveSuccess
        )
    }
}

private struct ProfileFormScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ProfileFormViewModel
    private let onSaveSuccess: ((Child) -> Void)?

    init(childRepository: ChildRepository, onSaveSuccess: ((Child) -> Void)? = nil) {
        _viewModel = State(initialValue: ProfileFormViewModel(childRepository: childRepository))
        self.onSaveSuccess = onSaveSuccess
    }

    init(viewModel: ProfileFormViewModel, onSaveSuccess: ((Child) -> Void)? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.onSaveSuccess = onSaveSuccess
    }

    var body: some View {
        ZStack {
            VStack(spacing: 30) {
                // top bar
                ZStack {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .padding(20)
                        }
                        .glassEffect(in: Circle())
                        
                        Spacer()
                    }
                    
                    Text("Child Profile Setup")
                        .font(.system(size: 20, weight: .bold))
                }
                
                // profile name selection
                VStack (alignment: .leading) {
                    Text("Child's Name")
                    PrimaryTextField(
                        text: $viewModel.childName,
                        placeholder: "Type name...",
                        size: .large,
                        systemImage: "person.crop.circle.fill"
                    )
                }
                
                // birthdate selection
                VStack (alignment: .leading) {
                    Text("Birthdate")
                    PrimaryDateField(
                        date: $viewModel.childsBirthday,
                        placeholder: "Insert Birthdate...",
                        size: .large,
                        systemImage: "calendar"
                    )
                }
                
                // gender selection
                HStack(spacing: 30) {
                    RadioButton(
                        title: "Male",
                        isSelected: viewModel.childIsMale,
                        action: { viewModel.selectGender(isMale: true) }
                    )
                    
                    RadioButton(
                        title: "Female",
                        isSelected: !viewModel.childIsMale,
                        action: { viewModel.selectGender(isMale: false) }
                    )
                    
                    Spacer()
                }
                
                // profile avatar
                VStack (alignment: .leading) {
                    Text("Choose Avatar")
                    ScrollView(.horizontal) {
                        HStack(spacing: 20) {
                            ForEach(ChildAvatarImage.allCases) { avatar in
                                ChildAvatarOption(
                                    avatar: avatar,
                                    isSelected: viewModel.selectedAvatar == avatar,
                                    action: { viewModel.selectAvatar(avatar) }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, -30)
                }
                .ignoresSafeArea()
                
                PrimaryButton(
                    title: "Save Child Profile",
                    size: .large,
                    systemImage: nil,
                    isDisabled: !viewModel.formCompleted,
                    action: viewModel.requestSave
                )
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .foregroundStyle(.textPrimary)
            .padding(.horizontal, 30)
            .padding(.vertical)
            
            if viewModel.showConfirmation {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        viewModel.cancelConfirmation()
                    }

                VStack(spacing: 30) {
                    Text("Save Child Profile")
                        .font(.headline)

                    Text(viewModel.confirmationMessage)
                        .foregroundStyle(.secondary)
                        .padding(.top, -20)

                    HStack(spacing: 15) {
                        SecondaryButton (
                            title: "Cancel",
                            size: .small,
                            action: viewModel.cancelConfirmation
                        )
                        .frame(maxWidth: .infinity)

                        PrimaryButton (
                            title: "Yes, Save",
                            size: .small,
                            action: saveConfirmedChild
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 40)
            }
        }
        .alert("Could Not Save Profile", isPresented: saveErrorPresented) {
            Button("OK", role: .cancel) {
                viewModel.saveError = nil
            }
        } message: {
            Text(viewModel.saveError ?? "")
        }
    }

    private func saveConfirmedChild() {
        guard let child = viewModel.makeChild(), viewModel.confirmSave() else { return }
        onSaveSuccess?(child)
        dismiss()
    }

    private var saveErrorPresented: Binding<Bool> {
        Binding(
            get: { viewModel.saveError != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.saveError = nil
                }
            }
        )
    }
}

#Preview {
    NavigationStack {
        ProfileFormView()
            .environment(\.childRepository, InMemoryChildRepository())
    }
}
