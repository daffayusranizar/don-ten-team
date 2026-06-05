//
//  DropDown.swift
//  team-10-c3
//
//  Created by Huy Tran on 27/05/26.
//

import SwiftUI

enum DropdownSize {
    case large
    case medium
    case small

    var horizontalPadding: CGFloat {
        switch self {
        case .large: 24
        case .medium: 18
        case .small: 14
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .large: 18
        case .medium: 14
        case .small: 10
        }
    }

    var contentSpacing: CGFloat {
        switch self {
        case .large: 12
        case .medium: 10
        case .small: 8
        }
    }

    var font: Font {
        switch self {
        case .large:
            .system(size: 20, weight: .medium)

        case .medium:
            .system(size: 18, weight: .medium)

        case .small:
            .system(size: 16, weight: .medium)
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .large: 50
        case .medium: 40
        case .small: 30
        }
    }

    var minHeight: CGFloat {
        switch self {
        case .large: 60
        case .medium: 50
        case .small: 40
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .large: 18
        case .medium: 14
        case .small: 10
        }
    }

    var optionSpacing: CGFloat {
        switch self {
        case .large: 8
        case .medium: 6
        case .small: 4
        }
    }

    var dropdownOffset: CGFloat {
        switch self {
        case .large: 90
        case .medium: 70
        case .small: 50
        }
    }

    var addButtonIconPadding: CGFloat {
        switch self {
        case .large: 10
        case .medium: 8
        case .small: 6
        }
    }
}

// MARK: Primary Textfield
struct PrimaryDropdown: View {
    @Environment(\.profileViewModel) private var profileViewModel
    @State private var isExpanded = false
    @Binding var selectedChild: Child?
    var allowsSelection: Bool = true
    var onAddChild: () -> Void = {}
    var size: DropdownSize = .medium
    var iconOption: String = "person.crop.circle.fill"

    private var displayName: String {
        selectedChild?.name ?? "Add a child"
    }

    var body: some View {
        // Dropdown Button
        Button {
            guard allowsSelection else { return }
            withAnimation(.snappy) {
                isExpanded.toggle()
            }
        } label: {
            HStack {
                if let selectedChild {
                    ProfileAvatarView(child: selectedChild, size: size.iconSize * 0.85)
                } else {
                    Image(systemName: iconOption)
                        .font(.system(size: size.iconSize * 0.7, weight: .semibold))
                        .foregroundStyle(.textPrimary)
                }

                Text(displayName)
                    .font(size.font)

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: size.iconSize * 0.5, weight: .semibold))
                    .rotationEffect(
                        .degrees(isExpanded ? 180 : 0)
                    )
            }
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .background(
                Capsule()
                    .fill(.uiSurface)
            )
        }
        .buttonStyle(.plain)
        .disabled(!allowsSelection)
        .opacity(allowsSelection ? 1 : 0.65)

        // Dropdown Options
        .overlay(alignment: .topLeading) {
            if isExpanded, allowsSelection {
                VStack(spacing: size.optionSpacing) {
                    ForEach(profileViewModel.children) { child in
                        Button {
                            guard allowsSelection else { return }
                            profileViewModel.selectChild(child)
                            selectedChild = child

                            withAnimation(.snappy) {
                                isExpanded = false
                            }
                        } label: {
                            HStack {
                                ProfileAvatarView(child: child, size: size.iconSize * 0.85)

                                Text(child.name)

                                Spacer()

                                if child.id == selectedChild?.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                            .font(size.font)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        withAnimation(.snappy) {
                            isExpanded = false
                        }
                        onAddChild()
                    } label: {
                        HStack(spacing: size.contentSpacing) {
                            Image(systemName: "plus")
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(
                                    Circle()
                                        .fill(.primaryMediumBlue)
                                )

                            Text("Add Child")
                                .font(size.font)

                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .padding()
                    }
                    .buttonStyle(.plain)
                }
                .background(.uiSurface)
                .clipShape(
                    RoundedRectangle(cornerRadius: size.cornerRadius)
                )

                // places menu below the button
                .padding(.top, size.dropdownOffset)
                .zIndex(999)
            }
        }
        .fontWeight(.medium)
        .frame(minHeight: size.minHeight)
        .zIndex(isExpanded ? 100 : 0)
    }
}

// MARK: Secondary Textfield
struct SecondaryDropdown: View {
    @State private var isExpanded = false
    @Binding var selectedOption: String // temp type, replace with model
    var size: DropdownSize = .medium
    
    // ! temporary until we have models
    var iconOption: String = "person.crop.circle.fill" // replace with Image type once model implemented
    @Binding var tempOptions: [String]
    
    var body: some View {
        // Dropdown Button
        Button {
            withAnimation(.snappy) {
                isExpanded.toggle()
            }
        } label: {
            HStack {
                Text(selectedOption)
                    .font(size.font)

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: size.iconSize * 0.5, weight: .semibold))
                    .rotationEffect(
                        .degrees(isExpanded ? 180 : 0)
                    )
            }
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .background(
                Capsule()
                    .fill(.uiSurface)
            )
        }
        .buttonStyle(.plain)

        // Dropdown Options
        .overlay(alignment: .top) {
            if isExpanded {
                VStack(spacing: size.optionSpacing) {
                    // each profile listing
                    ForEach(tempOptions, id: \.self) { option in
                        Button {
                            selectedOption = option

                            withAnimation(.snappy) {
                                isExpanded = false
                            }
                        } label: {
                            HStack {
                                Text(option)

                                Spacer()

                                if option == selectedOption {
                                    Image(systemName: "checkmark")
                                }
                            }
                            .font(size.font)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // ! temporary for add child
                    Button {
                        withAnimation(.snappy) {
                            isExpanded = false
                        }
                    } label: {
                        HStack(spacing: size.contentSpacing) {
                            Image(systemName: "plus")
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(
                                    Circle()
                                        .fill(.primaryMediumBlue)
                                )
                            
                            Text("Add Child")
                                .font(size.font)
                            
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .padding()
                    }
                    .buttonStyle(.plain)
                }
                .background(.uiSurface)
                .clipShape(
                    RoundedRectangle(cornerRadius: size.cornerRadius)
                )

                // places menu below the button
                .padding(.top, size.dropdownOffset)
            }
        }
        .fontWeight(.medium)
        .frame(minHeight: size.minHeight)
        .zIndex(isExpanded ? 100 : 0)
    }
}

// MARK: Tertiary Textfield
struct TertiaryDropdown: View {
    @State private var isExpanded = false
    @Binding var selectedOption: String // temp type, replace with model
    var size: DropdownSize = .medium
    
    // ! temporary until we have models
    var iconOption: String = "person.crop.circle.fill" // replace with Image type once model implemented
    @Binding var tempOptions: [String]
    
    var body: some View {
        // Dropdown Button
        Button {
            withAnimation(.snappy) {
                isExpanded.toggle()
            }
        } label: {
            HStack {
                Image(systemName: iconOption)
                    .font(.system(size: size.iconSize * 0.7, weight: .semibold))
                    .foregroundStyle(.textPrimary)

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: size.iconSize * 0.5, weight: .semibold))
                    .rotationEffect(
                        .degrees(isExpanded ? 180 : 0)
                    )
            }
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .background(
                Capsule()
                    .fill(.uiSurface)
            )
        }
        .buttonStyle(.plain)

        // Dropdown Options
        .overlay(alignment: .top) {
            if isExpanded {
                VStack(spacing: size.optionSpacing) {
                    // each profile listing
                    ForEach(tempOptions, id: \.self) { option in
                        Button {
                            selectedOption = option

                            withAnimation(.snappy) {
                                isExpanded = false
                            }
                        } label: {
                            HStack {
                                // temp icon
                                Image(systemName: iconOption)
                                    .font(.system(size: size.iconSize * 0.7, weight: .semibold))
                                    .foregroundStyle(.textPrimary)

                                Spacer()

                                if option == selectedOption {
                                    Image(systemName: "checkmark")
                                }
                            }
                            .font(size.font)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // ! temporary for add child
                    Button {
                        withAnimation(.snappy) {
                            isExpanded = false
                        }
                    } label: {
                        HStack(spacing: size.contentSpacing) {
                            Image(systemName: "plus")
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(
                                    Circle()
                                        .fill(.primaryMediumBlue)
                                )
                            
                            Text("Add Child")
                                .font(size.font)
                            
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .padding()
                    }
                    .buttonStyle(.plain)
                }
                .background(.uiSurface)
                .clipShape(
                    RoundedRectangle(cornerRadius: size.cornerRadius)
                )

                // places menu below the button
                .padding(.top, size.dropdownOffset)
            }
        }
        .fontWeight(.medium)
        .frame(minHeight: size.minHeight)
        .zIndex(isExpanded ? 100 : 0)
    }
}

#Preview("Primary Dropdown") {
    @Previewable @State var selectedChild: Child? = Child(
        name: "Raka Fadhilah",
        dateOfBirth: Calendar.current.date(byAdding: .year, value: -8, to: Date()) ?? Date(),
        gender: .boy
    )
    let repository = InMemoryChildRepository()
    let profileViewModel = ProfileViewModel(childRepository: repository)

    NavigationStack {
        ZStack {
            VStack(spacing: 20) {
                PrimaryDropdown(
                    selectedChild: $selectedChild,
                    size: .large
                )

                PrimaryDropdown(
                    selectedChild: $selectedChild,
                    size: .medium
                )

                PrimaryDropdown(
                    selectedChild: $selectedChild,
                    size: .small
                )
            }
            .padding()
        }
        .environment(\.profileViewModel, profileViewModel)
        .environment(\.childRepository, repository)
        .onAppear {
            if let selectedChild {
                try? repository.save(selectedChild)
                try? repository.save(
                    Child(
                        name: "John Doe",
                        dateOfBirth: Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date(),
                        gender: .boy
                    )
                )
                profileViewModel.loadChildren()
            }
        }
    }
}

#Preview("Secondary Dropdown") {
    @Previewable @State var exampleName: String = "Raka Fadhilah"
    @Previewable @State var exampleOptions: [String] = ["Raka Fadhilah", "John Doe"]
    
    ZStack {
        VStack(spacing: 20) {
            SecondaryDropdown(
                selectedOption: $exampleName,
                size: .large,
                tempOptions: $exampleOptions
            )
            
            SecondaryDropdown(
                selectedOption: $exampleName,
                size: .medium,
                tempOptions: $exampleOptions
            )
            
            SecondaryDropdown(
                selectedOption: $exampleName,
                size: .small,
                tempOptions: $exampleOptions
            )
        }
        .padding()
    }
}

#Preview("Tertiary Dropdown") {
    @Previewable @State var exampleName: String = "Raka Fadhilah"
    @Previewable @State var exampleOptions: [String] = ["Raka Fadhilah", "John Doe"]
    
    ZStack {
        VStack(spacing: 20) {
            TertiaryDropdown(
                selectedOption: $exampleName,
                size: .large,
                tempOptions: $exampleOptions
            )
            
            TertiaryDropdown(
                selectedOption: $exampleName,
                size: .medium,
                tempOptions: $exampleOptions
            )
            
            TertiaryDropdown(
                selectedOption: $exampleName,
                size: .small,
                tempOptions: $exampleOptions
            )
        }
        .padding()
    }
}
