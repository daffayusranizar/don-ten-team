//
//  OnboardingView.swift
//  team-10-c3
//
//  Created by Huy Tran on 26/05/26.
//
// [P1] Multi-step setup container

import SwiftUI

struct OnboardingData {
    // step 3 data
    var childName = ""
    var childBirthdate: Date?
    var childIsMale = true
    var selectedAvatar: ChildAvatarImage?

    // step 4 data
    var selectedGoals: [ParentGoal] = []
}

struct OnboardingView: View {
    @State private var data = OnboardingData()

    var body: some View {
        NavigationStack {
            StepThreeView(data: $data)
        }
    }
}

#Preview {
    NavigationStack {
        OnboardingView()
    }
}
