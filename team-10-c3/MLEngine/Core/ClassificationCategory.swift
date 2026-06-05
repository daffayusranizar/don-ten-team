//
//  ClassificationCategory.swift
//  iamge-detection
//
//  3 categories. Image prompts score screenshots; audio prompts score tone + transcript.
//

import Foundation

public struct ClassificationCategory: Sendable, Equatable {
    public let name: String
    public let prompts: [String]
    
    public init(name: String, prompts: [String]) {
        self.name = name
        self.prompts = prompts
    }
}

public enum ClassificationCategories {
    public static let all: [ClassificationCategory] = PromptLibrary.Classification.all

    public static let audioAll: [ClassificationCategory] = PromptLibrary.Classification.audioAll

    public static var allPrompts: [String] {
        all.flatMap(\.prompts)
    }

    public static var audioPrompts: [String] {
        audioAll.flatMap(\.prompts)
    }

    public static var categoryNames: [String] {
        all.map(\.name)
    }

    public static func category(containing prompt: String) -> ClassificationCategory? {
        all.first { $0.prompts.contains(prompt) }
            ?? audioAll.first { $0.prompts.contains(prompt) }
    }
}
