//
//  DashboardView.swift
//  team-10-c3
//
//  Created by Huy Tran on 26/05/26.
//
// [P1] Child list + active session banner

import SwiftUI
import Charts

func nothing() -> Void {}

struct DashboardView: View {
    @Environment(\.profileViewModel) private var profileViewModel
    @State var showSettings: Bool = false
    struct SessionData: Identifiable {
        let id = UUID()
        let type: String
        let duration: Int
        let color: Color
    }
    
    let sessions: [SessionData] = [
        SessionData(type: "YouTube", duration: 90, color: .decorativeSkyBlue),
        SessionData(type: "TikTok", duration: 100, color: .decorativeSunnyYellow),
        SessionData(type: "Gallery", duration: 65, color: .decorativeMintGreen),
        SessionData(type: "Games", duration: 65, color: .decorativeCoralPink),
    ]
    // - temp
    
    var body: some View {
        @Bindable var profileViewModel = profileViewModel

        ScrollView(.vertical, showsIndicators: false) {
            ZStack(alignment: .top) {

                VStack(spacing: 0) {

                    Color.clear
                        .frame(height: 70)

                    // status thing?
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Latest Screen Time")
                            .font(Font.system(size: 24, weight: .semibold))

                        Text("Total")

                        Text("3H 4M")
                            .font(Font.system(size: 40, weight: .semibold))

                        VStack(alignment: .leading) {
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .foregroundStyle(.white)

                                Capsule()
                                    .frame(width: 230)
                                    .foregroundStyle(.primaryTeal)
                            }
                            .frame(height: 12)
                            Text("75% of the session")
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 25)
                    .foregroundStyle(.white)
                    .background(.primaryMediumBlue)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 25)
                    )
                    .padding(.top, 30)

                    // latest summary
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Latest Summary")
                                .font(.system(size: 22, weight: .semibold))
                            Spacer()
                        }

                        VStack(alignment: .center, spacing: 15) {
                            Text("Yesterday's Session")
                                .font(.system(size: 18, weight: .semibold))

                            // bar chart session breakdown
                            Chart(sessions) { session in
                                BarMark(
                                    x: .value("Type", session.type),
                                    y: .value("Duration", session.duration)
                                )
                                .foregroundStyle(session.color)
                                .clipShape(
                                    UnevenRoundedRectangle(
                                        topLeadingRadius: 15,
                                        bottomLeadingRadius: 0,
                                        bottomTrailingRadius: 0,
                                        topTrailingRadius: 15
                                    )
                                )
                            }
                            .chartXAxis {
                                AxisMarks { _ in
                                    AxisValueLabel()
                                    AxisTick()
                                }
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading) { value in
                                    AxisValueLabel {
                                        if let number = value.as(Double.self) {
                                            Text("\(Int(number))min")
                                        }
                                    }
                                    AxisTick()
                                }
                            }
                            .chartPlotStyle { plotArea in
                                plotArea
                                    .border(.clear)
                            }
                            .padding()
                            .background(.uiBackground)
                            .clipShape(
                                RoundedRectangle(cornerRadius: 15)
                            )

                            // most used apps list
                            VStack {
                                HStack {
                                    Text("Most Used Apps")
                                        .font(.system(size: 16, weight: .semibold))
                                    Spacer()
                                }

                                VStack {
                                    HStack {
                                        ImageAsset.instagram.image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 30, height: 30)
                                            .cornerRadius(10)

                                        Text("Instagram")
                                            .font(.system(size: 14, weight: .regular))

                                        Spacer()

                                        Text("2 Hours 30 Minutes")
                                            .font(.system(size: 14, weight: .medium))
                                    }

                                    HStack {
                                        ImageAsset.tiktok.image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 30, height: 30)
                                            .cornerRadius(10)

                                        Text("TikTok")
                                            .font(.system(size: 14, weight: .regular))

                                        Spacer()

                                        Text("50 Minutes")
                                            .font(.system(size: 14, weight: .medium))
                                    }

                                    HStack {
                                        ImageAsset.youtube.image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 30, height: 30)
                                            .cornerRadius(10)

                                        Text("YouTube")
                                            .font(.system(size: 14, weight: .regular))

                                        Spacer()

                                        Text("20 Minutes")
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                }
                            }
                            .padding()
                            .background(.uiBackground)
                            .clipShape(
                                RoundedRectangle(cornerRadius: 15)
                            )

                        }
                        .padding(.horizontal, 15)
                        .padding(.vertical, 30)
                        .background(.decorativeSkyBlue.opacity(0.13))
                        .clipShape(
                            RoundedRectangle(cornerRadius: 15)
                        )
                    }
                    .padding(.top, 30)
                }
                .padding(.horizontal, 30)
                .padding(.vertical)
                .foregroundStyle(.textPrimary)

                // tool bar
                HStack {
                    PrimaryDropdown(
                        selectedChild: $profileViewModel.selectedChild
                    )

                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 20, weight: .semibold))
                            .padding()
                            .background(
                                Circle()
                                    .fill(.uiSurface)
                            )
                    }
                }
                .foregroundStyle(.textPrimary)
                .padding(.horizontal, 30)
                .padding(.vertical)
                .zIndex(1000)
            }
        }
        .navigationDestination(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
}
