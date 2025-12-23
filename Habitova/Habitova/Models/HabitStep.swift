//
//  HabitStep.swift
//  Habitova
//
//  Created by Claude on 2025/12/23.
//

import Foundation
import SwiftData

@Model
final class HabitStep {
    var id: UUID
    var habitId: UUID
    var stepNumber: Int
    var title: String
    var stepDescription: String?
    var isOptional: Bool
    var estimatedTimeMinutes: Int?
    var isCompleted: Bool
    var completedAt: Date?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        habitId: UUID,
        stepNumber: Int,
        title: String,
        stepDescription: String? = nil,
        isOptional: Bool = false,
        estimatedTimeMinutes: Int? = nil
    ) {
        self.id = id
        self.habitId = habitId
        self.stepNumber = stepNumber
        self.title = title
        self.stepDescription = stepDescription
        self.isOptional = isOptional
        self.estimatedTimeMinutes = estimatedTimeMinutes
        self.isCompleted = false
        self.completedAt = nil
        self.notes = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Step Management Extensions
extension HabitStep {
    /// ステップを完了としてマーク
    func markAsCompleted(notes: String? = nil) {
        isCompleted = true
        completedAt = Date()
        self.notes = notes
        updatedAt = Date()
    }
    
    /// ステップの完了をリセット
    func resetCompletion() {
        isCompleted = false
        completedAt = nil
        notes = nil
        updatedAt = Date()
    }
    
    /// ステップが時間制限内に完了されたかチェック
    func isCompletedWithinTimeLimit() -> Bool {
        guard let completedAt = completedAt,
              let estimatedTimeMinutes = estimatedTimeMinutes else {
            return isCompleted
        }
        
        let timeElapsed = Date().timeIntervalSince(completedAt) / 60 // 分に変換
        return isCompleted && timeElapsed <= Double(estimatedTimeMinutes)
    }
    
    /// ステップの進行状況（割合）
    var progressPercentage: Double {
        return isCompleted ? 1.0 : 0.0
    }
}

// MARK: - JSON Export Support
extension HabitStep {
    /// JSONエクスポート用の辞書表現
    var exportDictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id.uuidString,
            "habitId": habitId.uuidString,
            "stepNumber": stepNumber,
            "title": title,
            "isOptional": isOptional,
            "isCompleted": isCompleted,
            "createdAt": createdAt.ISO8601Format(),
            "updatedAt": updatedAt.ISO8601Format()
        ]
        
        if let stepDescription = stepDescription {
            dict["stepDescription"] = stepDescription
        }
        
        if let estimatedTimeMinutes = estimatedTimeMinutes {
            dict["estimatedTimeMinutes"] = estimatedTimeMinutes
        }
        
        if let completedAt = completedAt {
            dict["completedAt"] = completedAt.ISO8601Format()
        }
        
        if let notes = notes {
            dict["notes"] = notes
        }
        
        return dict
    }
}