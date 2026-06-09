//
//  OnboardingView.swift
//  team-10-c3
//
//  Created by Huy Tran on 26/05/26.
//
// [P1] Multi-step setup container

import SwiftUI

struct OnboardingData {
    // step 1 data (parents)
    var parentName = ""
    var parentBirthdate: Date?
    var parentPin: String?
    
    // step 2 data (family situation)
    var familySituation: FamilySituation?
    
    // step 3 data (child)
    var childName = ""
    var childBirthdate: Date?
    var childIsMale: Bool = true
    var selectedAvatar: ChildAvatarImage? = .avatar1

    // step 4 data (most important goals)
    var selectedGoals: [ParentGoal] = []
    
    // step 5 data (reminders)
    var weeklySuggestions: Bool = false
    var weeklyCheckIns: Bool = false
}

struct OnboardingView: View {
    @State private var data = OnboardingData()

    var body: some View {
        NavigationStack {
            StepOneView(data: $data)
        }
    }
}

#Preview {
    let repository = InMemoryChildRepository()
    let profileViewModel = ProfileViewModel(childRepository: repository)
    
    NavigationStack {
        OnboardingView()
    }
    .environment(\.childRepository, repository)
    .environment(\.profileViewModel, profileViewModel)
}
