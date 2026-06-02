//
//  ProfileViewModel.swift
//  team-10-c3
//
//  Created by Huy Tran on 26/05/26.
//
// [P1]

import Foundation
import Observation

@Observable
@MainActor
final class ProfileViewModel {
    private let childRepository: ChildRepository

    private(set) var children: [Child] = []
    var selectedChild: Child?
    var loadError: String?

    init(childRepository: ChildRepository) {
        self.childRepository = childRepository
    }

    func loadChildren() {
        do {
            children = try childRepository.fetchAll()
            loadError = nil

            if selectedChild == nil {
                selectedChild = children.first
            } else if let selectedChild,
                      !children.contains(where: { $0.id == selectedChild.id }) {
                self.selectedChild = children.first
            }
        } catch {
            loadError = error.localizedDescription
        }
    }

    func handleChildSaved(_ child: Child) {
        loadChildren()
        selectedChild = child
    }

    func selectChild(_ child: Child) {
        selectedChild = child
    }
}
