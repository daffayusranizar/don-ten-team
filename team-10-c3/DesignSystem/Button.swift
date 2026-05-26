//
//  Button.swift
//  team-10-c3
//
//  Created by Huy Tran on 26/05/26.
//

import SwiftUI


enum PrimaryButtonSize {
    case large
    case medium
    case small

    var horizontalPadding: CGFloat {
        switch self {
        case .large: 54
        case .medium: 42
        case .small: 30
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .large: 22
        case .medium: 16
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

    var font: Font {
        switch self {
        case .large: .system(size: 17, weight: .medium)
        case .medium: .system(size: 15, weight: .medium)
        case .small: .system(size: 12, weight: .medium)
        }
    }
}

// MARK: - PrimaryButton

struct PrimaryButton: View {
    let title: String
    var size: PrimaryButtonSize = .medium
    var systemImage: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: size.contentSpacing) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(size.font)
                }
                Text(title)
                    .font(size.font)
            }
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(Color("primaryMediumBlue"))
            .clipShape(Capsule())
            .foregroundStyle(.white)
        }
        .buttonStyle(PrimaryButtonStyle())
    }
}

// MARK: - ButtonStyle

private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

// MARK: - Preview

#Preview("Sizes") {
    VStack(spacing: 16) {
        PrimaryButton(title: "Get Started", size: .large) {}
        PrimaryButton(title: "Continue", size: .medium, systemImage: "arrow.right") {}
        PrimaryButton(title: "Try This Game", size: .small) {}
    }
    .padding()
}
