//
//  HabitChain.swift
//  Habitova
//
//  Created by Claude on 2025/12/21.
//

import Foundation
import SwiftData

@Model
final class HabitChain {
    var id: UUID
    var triggerHabitsData: Data // JSON encoded UUID array
    var prerequisiteHabitsData: Data? // JSON encoded prerequisite information
    var nextHabitId: UUID
    var delayMinutes: Int
    var triggerConditionData: Data // JSON encoded trigger condition
    var isAutomatic: Bool
    var confidence: Double?
    var frequency: Int
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        triggerHabits: [UUID],
        prerequisiteHabits: [String: Any]? = nil,
        nextHabitId: UUID,
        delayMinutes: Int = 0,
        triggerCondition: TriggerCondition,
        isAutomatic: Bool = false,
        confidence: Double? = nil,
        frequency: Int = 0,
        isActive: Bool = true
    ) {
        self.id = id
        self.nextHabitId = nextHabitId
        self.delayMinutes = delayMinutes
        self.isAutomatic = isAutomatic
        self.confidence = confidence
        self.frequency = frequency
        self.isActive = isActive
        self.createdAt = Date()
        self.updatedAt = Date()
        
        // Encode data
        self.triggerHabitsData = (try? JSONEncoder().encode(triggerHabits)) ?? Data()
        self.triggerConditionData = (try? JSONEncoder().encode(triggerCondition)) ?? Data()
        
        if let prerequisiteHabits = prerequisiteHabits {
            // Note: For now, storing as simplified data. Can be expanded later.
            self.prerequisiteHabitsData = try? JSONSerialization.data(withJSONObject: prerequisiteHabits)
        }
    }
}

// MARK: - Supporting Structures
struct TriggerCondition: Codable, Sendable {
    let type: String // "timeAfter", "immediately", "contextual"
    let delayMinutes: Int?
    let context: String?
}

// MARK: - Computed Properties
extension HabitChain {
    var triggerHabits: [UUID] {
        get {
            guard let habits = try? JSONDecoder().decode([UUID].self, from: triggerHabitsData) else {
                return []
            }
            return habits
        }
        set {
            triggerHabitsData = (try? JSONEncoder().encode(newValue)) ?? Data()
            updatedAt = Date()
        }
    }
    
    var triggerCondition: TriggerCondition? {
        get {
            return try? JSONDecoder().decode(TriggerCondition.self, from: triggerConditionData)
        }
        set {
            if let newValue = newValue {
                triggerConditionData = (try? JSONEncoder().encode(newValue)) ?? Data()
                updatedAt = Date()
            }
        }
    }
}