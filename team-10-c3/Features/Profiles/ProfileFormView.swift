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
    @State private var childName = ""
    @State private var birthdate: Date?
    @State private var isMale = true
    @State private var selectedAvatar: ChildAvatarImage = .avatar1
    @FocusState private var isNameFocused: Bool
    private let onSaveSuccess: ((Child) -> Void)?

    init(childRepository: ChildRepository, onSaveSuccess: ((Child) -> Void)? = nil) {
        let model = ProfileFormViewModel(childRepository: childRepository)
        _viewModel = State(initialValue: model)
        _birthdate = State(initialValue: model.childsBirthday)
        _isMale = State(initialValue: model.childIsMale)
        _selectedAvatar = State(initialValue: model.selectedAvatar)
        self.onSaveSuccess = onSaveSuccess
    }

    init(viewModel: ProfileFormViewModel, onSaveSuccess: ((Child) -> Void)? = nil) {
        _viewModel = State(initialValue: viewModel)
        _birthdate = State(initialValue: viewModel.childsBirthday)
        _isMale = State(initialValue: viewModel.childIsMale)
        _selectedAvatar = State(initialValue: viewModel.selectedAvatar)
        self.onSaveSuccess = onSaveSuccess
    }

    private var formCompleted: Bool {
        !childName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && birthdate != nil
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ProfileFormNameSection(
                    childName: $childName,
                    isFocused: $isNameFocused
                )
                .padding(.horizontal, 30)
                .padding(.top)

                ScrollView {
                    VStack(spacing: 30) {
                        ProfileFormBirthdateSection(birthdate: $birthdate)
                            .defocusNameField($isNameFocused)

                        ProfileFormGenderSection(isMale: $isMale)
                            .defocusNameField($isNameFocused)

                        ProfileFormAvatarSection(selectedAvatar: $selectedAvatar)
                            .defocusNameField($isNameFocused)

                        ProfileFormSaveButton(
                            isDisabled: !formCompleted,
                            action: requestSave
                        )
                        .defocusNameField($isNameFocused)
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isNameFocused = false
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Child Profile Setup")
            .navigationBarTitleDisplayMode(.inline)
            .foregroundStyle(.textPrimary)

            if viewModel.showConfirmation {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        viewModel.cancelConfirmation()
                    }

                VStack(spacing: 30) {
                    Text("Save Child Profile")
                        .font(.headline)

                    Text(confirmationMessage)
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
        .dismissKeyboardOnTap()
    }

    private var confirmationMessage: String {
        "You'll be adding \(childName) to your family. Do you want to continue?"
    }

    private func syncFormToViewModel() {
        viewModel.childName = childName
        viewModel.childsBirthday = birthdate
        viewModel.childIsMale = isMale
        viewModel.selectedAvatar = selectedAvatar
    }

    private func requestSave() {
        isNameFocused = false
        syncFormToViewModel()
        viewModel.requestSave()
    }

    private func saveConfirmedChild() {
        syncFormToViewModel()
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

private extension View {
    func defocusNameField(_ isFocused: FocusState<Bool>.Binding) -> some View {
        onTapGesture {
            isFocused.wrappedValue = false
        }
    }
}

private struct ProfileFormNameSection: View {
    @Binding var childName: String
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading) {
            Text("Child's Name")
            PrimaryTextField(
                text: $childName,
                placeholder: "Type name...",
                size: .large,
                systemImage: "person.crop.circle.fill",
                isFocused: $isFocused
            )
        }
    }
}

private struct ProfileFormBirthdateSection: View {
    @Binding var birthdate: Date?

    var body: some View {
        VStack(alignment: .leading) {
            Text("Birthdate")
            PrimaryDateField(
                date: $birthdate,
                placeholder: "Insert Birthdate...",
                size: .large,
                systemImage: "calendar"
            )
        }
    }
}

private struct ProfileFormGenderSection: View {
    @Binding var isMale: Bool

    var body: some View {
        HStack(spacing: 30) {
            RadioButton(
                title: "Male",
                isSelected: isMale,
                action: { isMale = true }
            )

            RadioButton(
                title: "Female",
                isSelected: !isMale,
                action: { isMale = false }
            )

            Spacer()
        }
    }
}

private struct ProfileFormAvatarSection: View {
    @Binding var selectedAvatar: ChildAvatarImage

    var body: some View {
        VStack(alignment: .leading) {
            Text("Choose Avatar")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(ChildAvatarImage.allCases) { avatar in
                        ChildAvatarOption(
                            avatar: avatar,
                            isSelected: selectedAvatar == avatar,
                            action: { selectedAvatar = avatar }
                        )
                    }
                }
                .padding(.vertical)
                .padding(.leading, 20)
            }
            .padding(.horizontal, -30)
        }
    }
}

private struct ProfileFormSaveButton: View {
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        PrimaryButton(
            title: "Save Child Profile",
            size: .large,
            systemImage: nil,
            isDisabled: isDisabled,
            action: action
        )
    }
}

extension View {
    func childProfileFormSheet(
        isPresented: Binding<Bool>,
        onSave: @escaping (Child) -> Void
    ) -> some View {
        sheet(isPresented: isPresented) {
            NavigationStack {
                ProfileFormView(onSaveSuccess: onSave)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProfileFormView()
            .environment(\.childRepository, InMemoryChildRepository())
    }
}
