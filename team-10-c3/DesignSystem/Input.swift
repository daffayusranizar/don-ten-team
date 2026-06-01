//
//  Input.swift
//  team-10-c3
//
//  Created by Huy Tran on 27/05/26.
//
import SwiftUI

enum TextFieldSize {
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
            .system(size: 18, weight: .regular)

        case .medium:
            .system(size: 16, weight: .regular)

        case .small:
            .system(size: 14, weight: .regular)
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .large: 22
        case .medium: 18
        case .small: 16
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
        case .large: 12
        case .medium: 10
        case .small: 8
        }
    }
}

// MARK: Primary Textfield
struct PrimaryTextField: View {
    @Binding var text: String
    var placeholder: String
    var size: TextFieldSize = .medium
    var systemImage: String? = nil
    var action: () -> Void = {}
    
    var body: some View {
        HStack(spacing: size.contentSpacing) {
            // TextField Icon (Optional)
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: size.iconSize))
                    .foregroundStyle(.textPrimary)
            }

            TextField(placeholder, text: $text)
                .font(size.font)
                .foregroundColor(.textPrimary)
                .onSubmit { action() }
            
            // Clear Text Button
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: size.iconSize))
                        .foregroundStyle(.textPrimary)
                }
            }
        }
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .frame(minHeight: size.minHeight)
        .background(
            Capsule()
                .fill(.uiSurface)
        )
    }
}

// MARK: Primary Date Input
struct PrimaryDateField: View {
    @Binding var date: Date?

    var placeholder: String
    var size: TextFieldSize = .medium
    var systemImage: String? = nil

    private var formattedDate: String {
        guard let date else { return placeholder }

        return date.formatted(
            .dateTime
                .day()
                .month(.abbreviated)
                .year()
        )
    }

    var body: some View {
        HStack(spacing: size.contentSpacing) {

            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: size.iconSize))
                    .foregroundStyle(.textPrimary)
            }

            ZStack(alignment: .leading) {

                // placeholder / formatted text
                Text(formattedDate)
                    .font(size.font)
                    .foregroundStyle(
                        date == nil
                        ? .textDisabled
                        : .textPrimary
                    )

                // actual picker
                DatePicker(
                    "",
                    selection: Binding(
                        get: { date ?? Date() },
                        set: { date = $0 }
                    ),
                    displayedComponents: [.date]
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .colorMultiply(.clear)
                
                if date != nil {
                    HStack {
                        Spacer()
                        
                        Button {
                            date = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: size.iconSize))
                                .foregroundStyle(.textPrimary)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .frame(minHeight: size.minHeight)
        .background(
            Capsule()
                .fill(.uiSurface)
        )
    }
}

// MARK: Secondary Textfield
struct SecondaryTextField: View {
    @Binding var text: String
    var placeholder: String
    var size: TextFieldSize = .medium
    var systemImage: String? = nil
    var action: () -> Void = {}
    
    var body: some View {
        HStack(spacing: size.contentSpacing) {
            // TextField Icon (Optional)
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: size.iconSize))
                    .foregroundStyle(.textPrimary)
            }

            TextField(placeholder, text: $text)
                .font(size.font)
                .foregroundColor(.textPrimary)
                .onSubmit { action() }
            
            // Clear Text Button
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: size.iconSize))
                        .foregroundStyle(.textPrimary)
                }
            }
        }
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .frame(minHeight: size.minHeight)
        .background(
            RoundedRectangle(cornerRadius: size.cornerRadius)
            .fill(.uiSurface)
        )
    }
}

// MARK: Preview
#Preview("Primary Input") {
    @Previewable @State var example1 = ""
    @Previewable @State var example2 = ""
    @Previewable @State var example3 = ""
    @Previewable @State var example4: Date? = nil
    
    ZStack {
        Color.black
            .ignoresSafeArea()
        
        VStack(spacing: 16) {
            PrimaryTextField(
                text: $example1,
                placeholder: "Type name...",
                size: .large,
                systemImage: "person.crop.circle.fill"
            )
            PrimaryDateField(
                date: $example4,
                placeholder: "Insert Birthdate...",
                size: .large,
                systemImage: "person.crop.circle.fill"
            )
            
            PrimaryTextField(
                text: $example2,
                placeholder: "Type name...",
                size: .medium,
                systemImage: "person.crop.circle.fill"
            )
            PrimaryDateField(
                date: $example4,
                placeholder: "Insert Birthdate...",
                size: .medium,
                systemImage: "person.crop.circle.fill"
            )
            
            PrimaryTextField(
                text: $example3,
                placeholder: "Type name...",
                size: .small,
                systemImage: "person.crop.circle.fill"
            )
            PrimaryDateField(
                date: $example4,
                placeholder: "Insert Birthdate...",
                size: .small,
                systemImage: "person.crop.circle.fill"
            )
        }
        .padding()
    }
}

#Preview("Secondary Input") {
    @Previewable @State var example1 = ""
    @Previewable @State var example2 = ""
    @Previewable @State var example3 = ""
    
    ZStack {
        Color.black
            .ignoresSafeArea()
        
        VStack(spacing: 16) {
            SecondaryTextField(
                text: $example1,
                placeholder: "Type name...",
                size: .large,
                systemImage: "person.crop.circle.fill"
            )
            
            SecondaryTextField(
                text: $example2,
                placeholder: "Type name...",
                size: .medium,
                systemImage: "person.crop.circle.fill"
            )
            
            SecondaryTextField(
                text: $example3,
                placeholder: "Type name...",
                size: .small,
                systemImage: "person.crop.circle.fill"
            )
        }
        .padding()
    }
}

