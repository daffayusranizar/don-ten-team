//
//  DashboardAddTimeView.swift
//  team-10-c3
//
//  Created by Huy Tran on 08/06/26.
//

import SwiftUI

// MARK: Additional Time Sheet View
func addTimeView(
    addingTime: Binding<Bool>,
    onAdd: @escaping (Int) -> Void
) -> some View {
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
                onAdd(totalSeconds)
                addingTime.wrappedValue = false
            }
        )
        .padding(.top, 20)
    }
    .padding()
}
