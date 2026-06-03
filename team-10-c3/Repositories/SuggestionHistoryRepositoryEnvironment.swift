//
//  SuggestionHistoryRepositoryEnvironment.swift
//  team-10-c3
//

import SwiftUI

extension EnvironmentValues {
    @Entry var suggestionHistoryRepository: SuggestionHistoryRepository =
        InMemorySuggestionHistoryRepository()
}
