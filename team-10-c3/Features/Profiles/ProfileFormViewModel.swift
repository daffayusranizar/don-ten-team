//
//  ProfileFormViewModel.swift
//  team-10-c3
//
//  Created by Huy Tran on 26/05/26.
//
// [P1] Create / edit child profile

import Foundation
import Observation

@Observable
@MainActor
final class ProfileFormViewModel {
    private let childRepository: ChildRepository

    var childName = ""
    var childsBirthday: Date?
    var childIsMale = true
    var selectedAvatar: ChildAvatarImage = .avatar1
    var showConfirmation = false
    var saveError: String?

    init(childRepository: ChildRepository) {
        self.childRepository = childRepository
        self.childsBirthday = Calendar.current.date(byAdding: .year, value: -10, to: Date())
    }

    var formCompleted: Bool {
        !childName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && childsBirthday != nil
    }

    var confirmationMessage: String {
        "You'll be adding \(childName) to your family. Do you want to continue?"
    }

    func selectGender(isMale: Bool) {
        childIsMale = isMale
    }

    func selectAvatar(_ avatar: ChildAvatarImage) {
        selectedAvatar = avatar
    }

    func requestSave() {
        guard formCompleted else { return }
        saveError = nil
        showConfirmation = true
    }

    func cancelConfirmation() {
        showConfirmation = false
    }

    @discardableResult
    func confirmSave() -> Bool {
        guard let child = makeChild() else { return false }

        do {
            try childRepository.save(child)
            saveError = nil
            showConfirmation = false
            return true
        } catch {
            saveError = error.localizedDescription
            return false
        }
    }

    func makeChild() -> Child? {
        guard let birthday = childsBirthday else { return nil }

        return Child(
            name: childName.trimmingCharacters(in: .whitespacesAndNewlines),
            dateOfBirth: birthday,
            gender: childIsMale ? .boy : .girl,
            avatarAssetName: selectedAvatar.asset.rawValue
        )
    }
}
