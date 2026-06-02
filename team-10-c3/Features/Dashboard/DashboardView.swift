//
//  DashboardView.swift
//  team-10-c3
//
//  Created by Huy Tran on 26/05/26.
//
// [P1] Child list + active session banner

import SwiftUI
import Charts

struct SessionData: Identifiable {
    let id = UUID()
    let type: String
    let duration: Int
    let color: Color
}

struct DashboardView: View {
    @Environment(\.profileViewModel) private var profileViewModel
    @State var showSettings: Bool = false
    @State var inSession: Bool = true
    @State var paused: Bool = false
    @State var addingTime: Bool = false

    let sessions: [SessionData] = [
        SessionData(type: "YouTube", duration: 90, color: .decorativeSkyBlue),
        SessionData(type: "TikTok", duration: 100, color: .decorativeSunnyYellow),
        SessionData(type: "Gallery", duration: 65, color: .decorativeMintGreen),
        SessionData(type: "Games", duration: 65, color: .decorativeCoralPink),
    ]

    var body: some View {
        @Bindable var profileViewModel = profileViewModel

        ScrollView(.vertical, showsIndicators: false) {
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: 70)

                    if inSession {
                        inSessionView(paused: $paused, addingTime: $addingTime)
                    } else {
                        previousSessionView()
                    }

                    latestSummary(sessions: sessions)
                }
                .padding(.horizontal, 30)
                .padding(.vertical)
                .foregroundStyle(.textPrimary)

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

// MARK: Latest Summary
@ViewBuilder
func latestSummary(sessions: [SessionData]) -> some View {
    VStack(alignment: .leading) {
        HStack {
            Text("Latest Summary")
                .font(.system(size: 22, weight: .semibold))
            Spacer()
        }

        VStack(alignment: .center, spacing: 15) {
            Text("Yesterday's Session")
                .font(.system(size: 18, weight: .semibold))

            sessionChart(sessions: sessions)

            mostUsedApps()
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

// MARK: Yesterday's Session Chart
@ViewBuilder
func sessionChart(sessions: [SessionData]) -> some View {
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
}

// MARK: Most Used Apps
@ViewBuilder
func mostUsedApps() -> some View {
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

// MARK: In Session View
@ViewBuilder
func inSessionView (paused: Binding<Bool>, addingTime: Binding<Bool>) -> some View {
    VStack(alignment: .leading, spacing: 15) {
        Text("Current Session")
            .font(Font.system(size: 24, weight: .semibold))

        HStack {
            Text("1H 20M")
                .font(Font.system(size: 40, weight: .semibold))

            Spacer()

            Button {
            } label: {
                Image(systemName: "stop.fill")
                    .font(Font.system(size: 20, weight: .semibold))
                    .padding(10)
                    .background(.white, in: Circle())
                    .foregroundStyle(.primaryMediumBlue)
            }

            Button {
                withAnimation {
                    paused.wrappedValue.toggle()
                }
            } label: {
                Image(systemName: paused.wrappedValue ? "play.fill" : "pause.fill")
                    .font(Font.system(size: 20, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))
                    .padding(10)
                    .background(.white, in: Circle())
                    .foregroundStyle(.primaryMediumBlue)
            }
        }

        VStack(alignment: .leading) {
            ZStack(alignment: .leading) {
                Capsule()
                    .foregroundStyle(.white)

                Capsule()
                    .frame(width: 230)
                    .foregroundStyle(.primaryTeal)
            }
            .frame(height: 12)
            Text("Time Limit: 1 Hour 30 Minutes")
        }

        Button {
            addingTime.wrappedValue = true
        } label: {
            Text("Add More Time")
                .padding()
                .frame(maxWidth: .infinity)
                .font(Font.system(size: 18, weight: .semibold))
                .foregroundStyle(.textPrimary)
                .background(
                    Capsule()
                        .fill(.white)
                )
        }
        .frame(maxWidth: .infinity)
        .sheet(isPresented: addingTime) {
            addTimeView(addingTime: addingTime)
            .presentationDetents([
                .fraction(0.5),
                .large
            ])
        }
        .foregroundStyle(.textPrimary)
    }
    .padding(.horizontal, 30)
    .padding(.vertical, 25)
    .foregroundStyle(.white)
    .background(.primaryMediumBlue)
    .clipShape(
        RoundedRectangle(cornerRadius: 25)
    )
    .padding(.top, 30)
}

// MARK: Previous Session View
@ViewBuilder
func previousSessionView() -> some View {
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
}

// MARK: Additional Time Sheet View
func addTimeView (addingTime: Binding<Bool>) -> some View {
    @State var hours = 0
    @State var minutes = 25 // defaults to 25 minutes for adding
    @State var seconds = 0
    
    // total time added as seconds
    var totalSeconds: Int {
        hours * 3600 + minutes * 60 + seconds
    }
    
    return VStack(alignment: .center) {
        // top bar
        ZStack {
            HStack {
                Button {
                    addingTime.wrappedValue = false
                } label: {
                    Image(systemName: "chevron.left")
                        .padding(20)
                }
                .glassEffect(in: Circle())
                
                Spacer()
            }
            
            Text("Add Additional Time")
                .font(.system(size: 20, weight: .semibold))
        }
        
        // time adder
        HStack {
            Picker("Hours", selection: $hours) {
                ForEach(0..<24) { hour in
                    Text("\(hour) h").tag(hour)
                }
            }

            Picker("Minutes", selection: $minutes) {
                ForEach(0..<60) { minute in
                    Text("\(minute) m").tag(minute)
                }
            }

            Picker("Seconds", selection: $seconds) {
                ForEach(0..<60) { second in
                    Text("\(second) s").tag(second)
                }
            }
        }
        .pickerStyle(.wheel)
        
        PrimaryButton(
            title: "Add Time",
            size: .large,
            action: {
                addingTime.wrappedValue = false
            } // temporary
        )
        .padding(.top, 20)
    }
    .padding()
}

#Preview {
    NavigationStack {
        DashboardView()
    }
}
