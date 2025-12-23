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
    
    // HabitStepへの関係性（リレーションシップではなくQueryで取得）
    // @Relationship(deleteRule: .cascade)
    // var steps: [HabitStep] = [] // SwiftDataの制限のため、直接リレーションシップではなく手動で管理
    
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

// MARK: - Step Management
extension Habit {
    /// この習慣のステップを取得
    func getSteps(from context: ModelContext) throws -> [HabitStep] {
        let habitId = self.id
        let fetchDescriptor = FetchDescriptor<HabitStep>(
            predicate: #Predicate<HabitStep> { step in
                step.habitId == habitId
            },
            sortBy: [SortDescriptor(\HabitStep.stepNumber)]
        )
        
        return try context.fetch(fetchDescriptor)
    }
    
    /// 新しいステップを追加
    func addStep(
        title: String,
        stepDescription: String? = nil,
        isOptional: Bool = false,
        estimatedTimeMinutes: Int? = nil,
        context: ModelContext
    ) throws {
        let existingSteps = try getSteps(from: context)
        let newStepNumber = (existingSteps.last?.stepNumber ?? 0) + 1
        
        let newStep = HabitStep(
            habitId: id,
            stepNumber: newStepNumber,
            title: title,
            stepDescription: stepDescription,
            isOptional: isOptional,
            estimatedTimeMinutes: estimatedTimeMinutes
        )
        
        context.insert(newStep)
    }
    
    /// ステップの完了状態をチェック
    func getStepCompletionStatus(from context: ModelContext) throws -> (completed: Int, total: Int, mandatory: Int, mandatoryCompleted: Int) {
        let steps = try getSteps(from: context)
        let completed = steps.filter { $0.isCompleted }.count
        let mandatory = steps.filter { !$0.isOptional }.count
        let mandatoryCompleted = steps.filter { !$0.isOptional && $0.isCompleted }.count
        
        return (completed: completed, total: steps.count, mandatory: mandatory, mandatoryCompleted: mandatoryCompleted)
    }
    
    /// すべての必須ステップが完了しているか
    func areAllMandatoryStepsCompleted(from context: ModelContext) throws -> Bool {
        let status = try getStepCompletionStatus(from: context)
        return status.mandatory == status.mandatoryCompleted
    }
    
    /// ステップの進捗状態（割合）
    func getStepProgress(from context: ModelContext) throws -> Double {
        let status = try getStepCompletionStatus(from: context)
        guard status.total > 0 else { return 1.0 }
        return Double(status.completed) / Double(status.total)
    }
    
    /// 必須ステップの進捗状態（割合）
    func getMandatoryStepProgress(from context: ModelContext) throws -> Double {
        let status = try getStepCompletionStatus(from: context)
        guard status.mandatory > 0 else { return 1.0 }
        return Double(status.mandatoryCompleted) / Double(status.mandatory)
    }
}