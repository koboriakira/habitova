//
//  ExecutionInference.swift
//  Habitova
//
//  Created by Claude on 2025/12/21.
//

import Foundation
import SwiftData

@Model
final class ExecutionInference {
    var id: UUID
    var userInput: String
    var inferredHabitsData: Data // JSON encoded inferred habits information
    var chainConsistencyCheckData: Data? // JSON encoded chain consistency check
    var proactiveQuestionsData: Data? // JSON encoded proactive questions
    var userFeedbackData: Data? // JSON encoded user feedback
    var debugInfoData: Data? // JSON encoded debug information
    var aiLearningAppliedData: Data? // JSON encoded AI learning information
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships
    var message: Message?
    
    init(
        id: UUID = UUID(),
        message: Message? = nil,
        userInput: String,
        inferredHabits: [InferredHabit] = [],
        chainConsistencyCheck: ChainConsistencyCheck? = nil,
        proactiveQuestions: [String]? = nil,
        userFeedback: [String: Any]? = nil,
        debugInfo: [String: Any]? = nil,
        aiLearningApplied: [String: Any]? = nil
    ) {
        self.id = id
        self.message = message
        self.userInput = userInput
        self.createdAt = Date()
        self.updatedAt = Date()
        
        // Encode data
        self.inferredHabitsData = (try? JSONEncoder().encode(inferredHabits)) ?? Data()
        
        if let chainConsistencyCheck = chainConsistencyCheck {
            self.chainConsistencyCheckData = try? JSONEncoder().encode(chainConsistencyCheck)
        }
        
        if let proactiveQuestions = proactiveQuestions {
            self.proactiveQuestionsData = try? JSONEncoder().encode(proactiveQuestions)
        }
    }
}

// MARK: - Supporting Structures
struct InferredHabit: Codable, Sendable {
    let habitId: UUID
    let habitName: String
    let executionType: ExecutionType
    let completionPercentage: Int
    let confidence: Double // 0.0 - 1.0
}

struct ChainConsistencyCheck: Codable, Sendable {
    let detectedChain: [UUID] // 実際に報告された順序
    let expectedChain: [UUID] // 定義に基づく期待される順序
    let skippedSteps: [UUID] // スキップされた習慣
    let unreportedSteps: [UUID] // 未報告の習慣
    let inconsistencyLevel: Double // 0.0 - 1.0
}

// MARK: - Computed Properties
extension ExecutionInference {
    var inferredHabits: [InferredHabit] {
        get {
            guard let habits = try? JSONDecoder().decode([InferredHabit].self, from: inferredHabitsData) else {
                return []
            }
            return habits
        }
        set {
            inferredHabitsData = (try? JSONEncoder().encode(newValue)) ?? Data()
            updatedAt = Date()
        }
    }
    
    var chainConsistencyCheck: ChainConsistencyCheck? {
        get {
            guard let data = chainConsistencyCheckData else { return nil }
            return try? JSONDecoder().decode(ChainConsistencyCheck.self, from: data)
        }
        set {
            if let newValue = newValue {
                chainConsistencyCheckData = try? JSONEncoder().encode(newValue)
            } else {
                chainConsistencyCheckData = nil
            }
            updatedAt = Date()
        }
    }
    
    var proactiveQuestions: [String]? {
        get {
            guard let data = proactiveQuestionsData else { return nil }
            return try? JSONDecoder().decode([String].self, from: data)
        }
        set {
            if let newValue = newValue {
                proactiveQuestionsData = try? JSONEncoder().encode(newValue)
            } else {
                proactiveQuestionsData = nil
            }
            updatedAt = Date()
        }
    }
}