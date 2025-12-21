//
//  HabitovaTask.swift
//  Habitova
//
//  Created by Claude on 2025/12/21.
//

import Foundation
import SwiftData

enum TaskType: String, Codable, CaseIterable, Sendable {
    case occasional = "occasional"    // 時々行う単発タスク
    case contextual = "contextual"    // 文脈的な単発タスク
}

@Model
final class HabitovaTask {
    var id: UUID
    var name: String
    var taskDescription: String
    var taskTypeRaw: String
    var relatedHabitsData: Data? // JSON encoded habit IDs
    var isParallelExecution: Bool
    var parallelWithData: Data? // JSON encoded UUID array
    var executedAt: Date
    var isIncludedInReport: Bool
    var isOnboardingCandidate: Bool
    var createdAt: Date
    
    // Relationships
    var message: Message?
    
    init(
        id: UUID = UUID(),
        message: Message? = nil,
        name: String,
        taskDescription: String = "",
        taskType: TaskType,
        relatedHabits: [UUID]? = nil,
        isParallelExecution: Bool = false,
        parallelWith: [UUID]? = nil,
        executedAt: Date = Date(),
        isIncludedInReport: Bool = true,
        isOnboardingCandidate: Bool = false
    ) {
        self.id = id
        self.message = message
        self.name = name
        self.taskDescription = taskDescription
        self.taskTypeRaw = taskType.rawValue
        self.isParallelExecution = isParallelExecution
        self.executedAt = executedAt
        self.isIncludedInReport = isIncludedInReport
        self.isOnboardingCandidate = isOnboardingCandidate
        self.createdAt = Date()
        
        if let relatedHabits = relatedHabits {
            self.relatedHabitsData = try? JSONEncoder().encode(relatedHabits)
        }
        
        if let parallelWith = parallelWith {
            self.parallelWithData = try? JSONEncoder().encode(parallelWith)
        }
    }
}

// MARK: - Computed Properties
extension HabitovaTask {
    var taskType: TaskType {
        get { TaskType(rawValue: taskTypeRaw) ?? .occasional }
        set { taskTypeRaw = newValue.rawValue }
    }
    
    var relatedHabitIds: [UUID]? {
        get {
            guard let data = relatedHabitsData else { return nil }
            return try? JSONDecoder().decode([UUID].self, from: data)
        }
        set {
            guard let newValue = newValue else {
                relatedHabitsData = nil
                return
            }
            relatedHabitsData = try? JSONEncoder().encode(newValue)
        }
    }
    
    var parallelWith: [UUID]? {
        get {
            guard let data = parallelWithData else { return nil }
            return try? JSONDecoder().decode([UUID].self, from: data)
        }
        set {
            guard let newValue = newValue else {
                parallelWithData = nil
                return
            }
            parallelWithData = try? JSONEncoder().encode(newValue)
        }
    }
}