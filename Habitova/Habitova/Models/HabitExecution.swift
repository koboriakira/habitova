//
//  HabitExecution.swift
//  Habitova
//
//  Created by Claude on 2025/12/21.
//

import Foundation
import SwiftData

enum ExecutionType: String, Codable, CaseIterable, Sendable {
    case direct = "direct"      // ユーザーが明示的に「やった」と言っている
    case partial = "partial"    // 部分的に完了した、または不確定
    case inferred = "inferred"  // 文脈から推測
}

@Model
final class HabitExecution {
    var id: UUID
    var executionTypeRaw: String
    var completionPercentage: Int
    var executedAt: Date
    var daysChain: Int // 連続実行日数
    var isParallelExecution: Bool
    var parallelWithData: Data? // JSON encoded UUID array
    var createdAt: Date
    
    // Relationships
    var habit: Habit?
    var message: Message?
    
    init(
        id: UUID = UUID(),
        habit: Habit? = nil,
        message: Message? = nil,
        executionType: ExecutionType,
        completionPercentage: Int = 100,
        executedAt: Date = Date(),
        daysChain: Int = 0,
        isParallelExecution: Bool = false,
        parallelWith: [UUID]? = nil
    ) {
        self.id = id
        self.habit = habit
        self.message = message
        self.executionTypeRaw = executionType.rawValue
        self.completionPercentage = completionPercentage
        self.executedAt = executedAt
        self.daysChain = daysChain
        self.isParallelExecution = isParallelExecution
        self.createdAt = Date()
        
        if let parallelWith = parallelWith {
            self.parallelWithData = try? JSONEncoder().encode(parallelWith)
        }
    }
}

// MARK: - Computed Properties
extension HabitExecution {
    var executionType: ExecutionType {
        get { ExecutionType(rawValue: executionTypeRaw) ?? .direct }
        set { executionTypeRaw = newValue.rawValue }
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