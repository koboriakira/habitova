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
    
    /// 前提条件習慣を指定してHabitChainを初期化するコンビニエンスイニシャライザ
    convenience init(
        id: UUID = UUID(),
        triggerHabits: [UUID],
        prerequisiteHabits: [PrerequisiteHabit]? = nil,
        nextHabitId: UUID,
        delayMinutes: Int = 0,
        triggerCondition: TriggerCondition,
        isAutomatic: Bool = false,
        confidence: Double? = nil,
        frequency: Int = 0,
        isActive: Bool = true
    ) {
        var prerequisiteData: [String: Any]? = nil
        if let prerequisites = prerequisiteHabits {
            // PrerequisiteHabitの配列をJSONエンコード可能な形式に変換
            if let encoded = try? JSONEncoder().encode(prerequisites),
               let jsonObject = try? JSONSerialization.jsonObject(with: encoded) {
                prerequisiteData = ["prerequisites": jsonObject]
            }
        }
        
        self.init(
            id: id,
            triggerHabits: triggerHabits,
            prerequisiteHabits: prerequisiteData,
            nextHabitId: nextHabitId,
            delayMinutes: delayMinutes,
            triggerCondition: triggerCondition,
            isAutomatic: isAutomatic,
            confidence: confidence,
            frequency: frequency,
            isActive: isActive
        )
    }
}

// MARK: - Supporting Structures
struct TriggerCondition: Codable, Sendable {
    let type: String // "timeAfter", "immediately", "contextual"
    let delayMinutes: Int?
    let context: String?
}

/// 前提条件となる習慣の情報
struct PrerequisiteHabit: Codable, Sendable {
    let habitId: UUID
    let habitName: String
    let isMandatory: Bool
    let estimatedTimeMinutes: Int?
    let description: String?
    
    init(habitId: UUID, habitName: String, isMandatory: Bool = true, estimatedTimeMinutes: Int? = nil, description: String? = nil) {
        self.habitId = habitId
        self.habitName = habitName
        self.isMandatory = isMandatory
        self.estimatedTimeMinutes = estimatedTimeMinutes
        self.description = description
    }
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
    
    /// 前提条件習慣の一覧を取得
    var prerequisiteHabits: [PrerequisiteHabit] {
        get {
            guard let data = prerequisiteHabitsData,
                  let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let prerequisitesArray = jsonObject["prerequisites"] else {
                return []
            }
            
            // JSONからPrerequisiteHabitの配列にデコード
            if let prerequisitesData = try? JSONSerialization.data(withJSONObject: prerequisitesArray),
               let prerequisites = try? JSONDecoder().decode([PrerequisiteHabit].self, from: prerequisitesData) {
                return prerequisites
            }
            return []
        }
        set {
            // PrerequisiteHabitの配列をJSONエンコード
            if let encoded = try? JSONEncoder().encode(newValue),
               let jsonObject = try? JSONSerialization.jsonObject(with: encoded) {
                let data = ["prerequisites": jsonObject]
                prerequisiteHabitsData = try? JSONSerialization.data(withJSONObject: data)
            } else {
                prerequisiteHabitsData = nil
            }
            updatedAt = Date()
        }
    }
    
    /// 前提条件習慣があるかどうか
    var hasPrerequisites: Bool {
        return !prerequisiteHabits.isEmpty
    }
}