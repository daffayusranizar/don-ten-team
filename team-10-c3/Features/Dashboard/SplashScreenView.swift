//
//  SplashScreenView.swift
//  team-10-c3
//
//  Created by Huy Tran on 10/06/26.
//

import SwiftUI

struct SplashScreenView: View {
    var statusMessage: String = "Starting Kiddly…"

    var body: some View {
        ZStack(alignment: .center) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.primaryMediumBlue, .primaryTeal],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image("SplashLogo")

                VStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.regular)
                        .tint(.white)

                    Text(statusMessage)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(maxWidth: 280)
                        .animation(.easeInOut(duration: 0.2), value: statusMessage)
                }
                .padding(.top, 8)
            }

            VStack(alignment: .trailing) {
                Spacer()

                HStack {
                    Spacer()
                    Image("SplashCorner")
                }
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}

#Preview {
    SplashScreenView(statusMessage: "Preparing on-device audio analysis…")
}
