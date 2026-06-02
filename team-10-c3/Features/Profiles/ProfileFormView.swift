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

struct tempAvatar: View {
    var body: some View {
        Button {
            
        } label: {
            Circle()
                .fill(.primaryMediumBlue)
                .frame(width: 80, height: 80)
        }
    }
}

struct ProfileFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var childName: String = ""
    @State private var childsBirthday: Date? = nil
    @State private var childIsMale: Bool = true
    @State private var showConfirmation: Bool = true
    
    private var formCompleted: Bool {
        !childName.isEmpty && childsBirthday != nil
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
                        text: $childName,
                        placeholder: "Type name...",
                        size: .large,
                        systemImage: "person.crop.circle.fill"
                    )
                }
                
                // birthdate selection
                VStack (alignment: .leading) {
                    Text("Birthdate")
                    PrimaryDateField(
                        date: $childsBirthday,
                        placeholder: "Insert Birthdate...",
                        size: .large,
                        systemImage: "calendar"
                    )
                }
                
                // gender selection
                HStack(spacing: 30) {
                    RadioButton(
                        title: "Male",
                        isSelected: childIsMale,
                        action: {childIsMale = true}
                    )
                    
                    RadioButton(
                        title: "Female",
                        isSelected: !childIsMale,
                        action: {childIsMale = false}
                    )
                    
                    Spacer()
                }
                
                // profile avatar
                VStack (alignment: .leading) {
                    Text("Choose Avatar")
                    ScrollView(.horizontal) {
                        HStack(spacing: 20) {
                            tempAvatar()
                            tempAvatar()
                            tempAvatar()
                            tempAvatar()
                            tempAvatar()
                            tempAvatar()
                            tempAvatar()
                        }
                    }
                    .padding(.horizontal, -30)
                }
                .ignoresSafeArea()
                
                PrimaryButton(
                    title: "Save Child Profile",
                    size: .large,
                    systemImage: nil,
                    isDisabled: !formCompleted,
                    action: {showConfirmation = true}
                )
                .frame(maxWidth: .infinity)
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .foregroundStyle(.textPrimary)
            .padding(.horizontal, 30)
            .padding(.vertical)
            
            if showConfirmation {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showConfirmation = false
                    }

                VStack(spacing: 20) {
                    Text("Save Child Profile")
                        .font(.headline)

                    Text("You'll be adding \(childName) to your family. Do you want to continue?")
                        .foregroundStyle(.secondary)

                    HStack(spacing: 15) {
                        SecondaryButton (
                            title: "Cancel",
                            size: .medium,
                            action: {showConfirmation = false}
                        )
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.glass)

                        PrimaryButton (
                            title: "Yes, Save",
                            size: .medium,
                            action: {showConfirmation = false}
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(30)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 40)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProfileFormView()
    }
}
