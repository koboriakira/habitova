//
//  Habit.swift
//  Habitova
//
//  Created by Claude on 2025/12/21.
//

import Foundation
import SwiftData

@Model
final class Habit {
    var id: UUID
    var name: String
    var habitDescription: String
    var targetFrequency: String // "daily", "weekly", "weekly_3times", "weekly_5times", "custom"
    var parentHabitId: UUID?
    var level: Int
    var importance: Double?
    var importanceInferred: Double?
    var hiddenParametersData: Data? // JSON encoded hiddenParameters
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \HabitExecution.habit)
    var executions: [HabitExecution] = []
    
    init(
        id: UUID = UUID(),
        name: String,
        habitDescription: String = "",
        targetFrequency: String = "daily",
        parentHabitId: UUID? = nil,
        level: Int = 0,
        importance: Double? = nil,
        importanceInferred: Double? = nil,
        hiddenParametersData: Data? = nil,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.habitDescription = habitDescription
        self.targetFrequency = targetFrequency
        self.parentHabitId = parentHabitId
        self.level = level
        self.importance = importance
        self.importanceInferred = importanceInferred
        self.hiddenParametersData = hiddenParametersData
        self.isArchived = isArchived
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Hidden Parameters Support
extension Habit {
    struct HiddenParameters: Codable, Sendable {
        let rigidityLevel: Double?
        let contextualTriggers: [String]?
        let seasonalVariation: Bool?
        let toleranceForFailure: Double?
        let emotionalSignificance: Double?
        let userRealisticExpectation: Double?
        let externalPressure: Double?
        let existingMomentum: Double?
    }
    
    var hiddenParameters: HiddenParameters? {
        get {
            guard let data = hiddenParametersData else { return nil }
            return try? JSONDecoder().decode(HiddenParameters.self, from: data)
        }
        set {
            guard let newValue = newValue else {
                hiddenParametersData = nil
                return
            }
            hiddenParametersData = try? JSONEncoder().encode(newValue)
            updatedAt = Date()
        }
    }
}