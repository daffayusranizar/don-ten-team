//
//  SessionSetupView.swift
//  team-10-c3
//
//  Created by Huy Tran on 02/06/26.
//

import SwiftUI

func nothing () -> Void {}

struct SessionSetupView: View {
    @State var hours = 0
    @State var minutes = 25 // defaults to 25 minutes for adding
    @State var seconds = 0
    
    // total time added as seconds
    var totalSeconds: Int {
        hours * 3600 + minutes * 60 + seconds
    }
    
    @State var recordScreen: Bool = false
    
    @Environment(\.profileViewModel) private var profileViewModel
    
    var body: some View {
        @Bindable var profileViewModel = profileViewModel
        
        ZStack(alignment: .top) {
            VStack(spacing: 18) {
                Color.clear
                    .frame(height: 200) // reserves space for toolbar + dropdown

                durationSection(hours: $hours, minutes: $minutes, seconds: $seconds)

                NotificationToggle(
                    title: "Record your screen",
                    isOn: $recordScreen
                )

                PrimaryButton(
                    title: "Start Session"
                ) {
                    nothing()
                }

                Spacer()
            }

            toolBar()
                .zIndex(1001)

            // child profile selection
            VStack(alignment: .leading, spacing: 4) {
                Text("Choose Your Child's Profile")

                PrimaryDropdown(
                    selectedChild: $profileViewModel.selectedChild
                )
            }
            .padding(.top, 100)
            .zIndex(1000)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .padding(.horizontal, 30)
        .foregroundStyle(.textPrimary)
    }
}

// MARK: Toolbar
func toolBar () -> some View {
    @Environment(\.dismiss) var dismiss
    
    return ZStack {
        HStack {
            // back button
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .padding()
                    .background(
                        Circle()
                            .fill(.uiSurface)
                    )
            }
            
            Spacer()
        }
        
        Text("Screen Time")
            .font(.system(size: 25, weight: .bold))
    }
}

func durationSection (hours: Binding<Int>, minutes: Binding<Int>, seconds: Binding<Int>) -> some View {
    return VStack(alignment: .leading) {
        Text("Duration")
        timeSelection(
            hours: hours,
            minutes: minutes,
            seconds: seconds
        )
    }
}

// MARK: Time Selection
func timeSelection (hours: Binding<Int>, minutes: Binding<Int>, seconds: Binding<Int>) -> some View {
    return VStack(alignment: .center) {
        // time picker
        HStack {
            Picker("Hours", selection: hours) {
                ForEach(0..<24) { hour in
                    Text("\(hour) h").tag(hour)
                }
            }

            Picker("Minutes", selection: minutes) {
                ForEach(0..<60) { minute in
                    Text("\(minute) m").tag(minute)
                }
            }

            Picker("Seconds", selection: seconds) {
                ForEach(0..<60) { second in
                    Text("\(second) s").tag(second)
                }
            }
        }
        .pickerStyle(.wheel)
        
        // quick select
        VStack(alignment: .leading) {
            Text("Quick Select")
            
            HStack {
                PrimaryButton(
                    title: "1 hour",
                    size: .small,
                    action: {
                        withAnimation {
                            hours.wrappedValue = 1
                        }
                    }
                )
                
                PrimaryButton(
                    title: "2 hour",
                    size: .small,
                    action: {
                        withAnimation {
                            hours.wrappedValue = 2
                        }
                    }
                )
                
                PrimaryButton(
                    title: "3 hour",
                    size: .small,
                    action: {
                        withAnimation {
                            hours.wrappedValue = 3
                        }
                    }
                )
            }
        }
    }
    .padding()
}

#Preview {
    NavigationStack {
        SessionSetupView()
    }
}
