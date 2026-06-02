//
//  Button.swift
//  team-10-c3
//
//  Created by Huy Tran on 26/05/26.
//

import SwiftUI

// MARK: - Size

enum ButtonSize {
    case large
    case medium
    case small

    var horizontalPadding: CGFloat {
        switch self {
        case .large: 54
        case .medium: 40
        case .small: 30
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .large: 22
        case .medium: 14
        case .small: 11
        }
    }

    var contentSpacing: CGFloat {
        switch self {
        case .large: 12
        case .medium: 10
        case .small: 8
        }
    }

    var primaryFont: Font {
        switch self {
        case .large: .system(size: 17, weight: .medium)
        case .medium: .system(size: 15, weight: .medium)
        case .small: .system(size: 12, weight: .medium)
        }
    }

    var secondaryFont: Font {
        switch self {
        case .large: .system(size: 17, weight: .medium)
        case .medium: .system(size: 15, weight: .medium)
        case .small: .system(size: 12, weight: .medium)
        }
    }
}
// MARK: - Toggle Button
struct NotificationToggle: View {
    let icon: String?
    let title: String
    @Binding var isOn: Bool

    init(
        icon: String? = nil,
        title: String,
        isOn: Binding<Bool>
    ) {
        self.icon = icon
        self.title = title
        self._isOn = isOn
    }

    var body: some View {
        HStack {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 25, weight: .semibold))
            }

            Text(title)

            Spacer()

            Toggle("", isOn: $isOn)
                .tint(.textPrimary)
        }
        .foregroundStyle(.textPrimary)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

// MARK: - PrimaryButton

struct PrimaryButton: View {
    let title: String
    var size: ButtonSize = .medium
    var systemImage: String? = nil
    var isDisabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            buttonLabel(font: size.primaryFont)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, size.horizontalPadding)
                .padding(.vertical, size.verticalPadding)
                .background(Color("primaryMediumBlue"))
                .clipShape(Capsule())
                .foregroundStyle(.white)
                .opacity(isDisabled ? 0.5 : 1)
        }
        .disabled(isDisabled)
        .buttonStyle(PressableButtonStyle())
    }

    @ViewBuilder
    private func buttonLabel(font: Font) -> some View {
        HStack(spacing: size.contentSpacing) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(font)
            }
            Text(title)
                .font(font)
        }
    }
}

// MARK: - SecondaryButton

struct SecondaryButton: View {
    let title: String
    var size: ButtonSize = .medium
    var systemImage: String? = nil
    var action: () -> Void

    private static let secondaryColor = Color.gray

    var body: some View {
        Button(action: action) {
            buttonLabel(font: size.secondaryFont)
                .padding(.horizontal, size.horizontalPadding)
                .padding(.vertical, size.verticalPadding)
                .foregroundStyle(Self.secondaryColor)
                .overlay(Capsule().stroke(Self.secondaryColor, lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
    }

    @ViewBuilder
    private func buttonLabel(font: Font) -> some View {
        HStack(spacing: size.contentSpacing) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(font)
            }
            Text(title)
                .font(font)
        }
    }
}

// MARK: - ButtonStyle

private struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

// MARK: - Preview

#Preview("Primary") {
    @Previewable @State var testBool: Bool = false
    
    VStack(spacing: 16) {
        NotificationToggle(title: "Test", isOn: $testBool)
        PrimaryButton(title: "Get Started", size: .large) {}
        PrimaryButton(title: "Continue", size: .medium, systemImage: "arrow.right") {}
        PrimaryButton(title: "Try This Game", size: .small) {}
    }
    .padding()
    .background(Color("uiBackground"))
}

#Preview("Secondary") {
    VStack(spacing: 16) {
        SecondaryButton(title: "Sign up", size: .large) {}
        SecondaryButton(title: "Sign up", size: .medium) {}
        SecondaryButton(title: "Sign up", size: .small) {}
    }
    .padding()
    .background(Color("uiBackground"))
}
