//
//  GuidanceCard.swift
//  team-10-c3
//
//  Created by Huy Tran on 26/05/26.
//
// [P2] Guidance recommendation card

import SwiftUI

private enum ActivityCardLayout {
    static let cornerRadius: CGFloat = 25
    static let contentPadding: CGFloat = 20
    static let ctaCornerRadius: CGFloat = 18
}

// MARK: - ActivityImagePlaceholder

struct ActivityImagePlaceholder: View {
    var height: CGFloat
    var cornerRadius: CGFloat = 0
    var showLabel: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.activityPlaceholder)
            .frame(height: height)
            .overlay {
                if showLabel {
                    Text("Images")
                        .font(.heading6)
                        .foregroundStyle(.textPrimary)
                }
            }
    }
}

// MARK: - ActivityCTAButton

struct ActivityCTAButton: View {
    let title: String
    var action: () -> Void

    private let size: ButtonSize = .small

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(size.primaryFont)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, size.verticalPadding)
                .background(.primaryMediumBlue)
                .clipShape(RoundedRectangle(cornerRadius: ActivityCardLayout.ctaCornerRadius))
        }
        .buttonStyle(ActivityCTAButtonStyle())
    }
}

private struct ActivityCTAButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

// MARK: - OfflineActivityCard

struct OfflineActivityCard: View {
    let title: String
    let description: String
    var onTryTapped: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ActivityImagePlaceholder(height: 95)

            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.textPrimary)

                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                ActivityCTAButton(title: "Try This Game", action: onTryTapped)
            }
            .padding(ActivityCardLayout.contentPadding)
        }
        .background(.uiBackground)
        .clipShape(RoundedRectangle(cornerRadius: ActivityCardLayout.cornerRadius))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 2, y: 2)
    }
}

// MARK: - Preview

#Preview("Offline Activity Card") {
    OfflineActivityCard(
        title: "2 Person Football Game",
        description: "Play short football passing challenges together to build teamwork, focus, and connection."
    )
    .padding()
    .background(.uiBackground)
}
