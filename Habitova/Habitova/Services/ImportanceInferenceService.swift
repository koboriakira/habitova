//
//  ImportanceInferenceService.swift
//  Habitova
//
//  Created by Claude on 2025/12/23.
//

import Foundation
import SwiftData

@MainActor
class ImportanceInferenceService {
    static let shared = ImportanceInferenceService()
    
    private init() {}
    
    // MARK: - Importance Inference
    
    /// 習慣の推測重要度を計算
    func calculateInferredImportance(
        for habit: Habit,
        context: ModelContext
    ) async -> Double {
        var score: Double = 0.5 // 基準値
        
        // 1. Hidden Parameters からの推測
        if let hiddenParams = habit.hiddenParameters {
            score += calculateHiddenParametersScore(hiddenParams)
        }
        
        // 2. 実行履歴からの推測
        score += await calculateExecutionHistoryScore(for: habit, context: context)
        
        // 3. チェーン内での位置からの推測
        score += await calculateChainPositionScore(for: habit, context: context)
        
        // 4. 時間的パターンからの推測
        score += await calculateTemporalPatternScore(for: habit, context: context)
        
        // 5. 外部圧力・感情的重要度の調整
        if let hiddenParams = habit.hiddenParameters {
            score += calculateContextualScore(hiddenParams)
        }
        
        // 0.0-1.0の範囲にクランプ
        return max(0.0, min(1.0, score))
    }
    
    /// Hidden Parametersからスコアを算出
    private func calculateHiddenParametersScore(_ params: Habit.HiddenParameters) -> Double {
        var score: Double = 0.0
        
        // 剛性レベル（高いほど重要）
        if let rigidity = params.rigidityLevel {
            score += rigidity * 0.15 // 最大0.15ポイント
        }
        
        // 失敗許容度（低いほど重要）
        if let tolerance = params.toleranceForFailure {
            score += (1.0 - tolerance) * 0.1 // 最大0.1ポイント
        }
        
        // 感情的重要度
        if let emotional = params.emotionalSignificance {
            score += emotional * 0.1 // 最大0.1ポイント
        }
        
        // 外部圧力
        if let pressure = params.externalPressure {
            score += pressure * 0.1 // 最大0.1ポイント
        }
        
        // 既存の勢い
        if let momentum = params.existingMomentum {
            score += momentum * 0.05 // 最大0.05ポイント
        }
        
        return score
    }
    
    /// 実行履歴からスコアを算出
    private func calculateExecutionHistoryScore(
        for habit: Habit,
        context: ModelContext
    ) async -> Double {
        do {
            let executions = try await getRecentExecutions(for: habit, context: context, days: 30)
            
            guard !executions.isEmpty else { return 0.0 }
            
            // 実行頻度（高いほど重要）
            let executionRate = Double(executions.count) / 30.0
            let frequencyScore = min(executionRate * 0.1, 0.1) // 最大0.1ポイント
            
            // 一貫性（安定した実行パターンがあるほど重要）
            let consistencyScore = calculateConsistencyScore(executions) * 0.05 // 最大0.05ポイント
            
            return frequencyScore + consistencyScore
            
        } catch {
            print("実行履歴スコア計算エラー: \(error)")
            return 0.0
        }
    }
    
    /// チェーン内での位置からスコアを算出
    private func calculateChainPositionScore(
        for habit: Habit,
        context: ModelContext
    ) async -> Double {
        do {
            // この習慣をトリガーとするチェーン数
            let triggerChains = try await getChainsWhereHabitIsTrigger(habit: habit, context: context)
            let triggerScore = min(Double(triggerChains.count) * 0.02, 0.06) // 最大0.06ポイント
            
            // この習慣が次の習慣になっているチェーン数
            let targetChains = try await getChainsWhereHabitIsTarget(habit: habit, context: context)
            let targetScore = min(Double(targetChains.count) * 0.02, 0.04) // 最大0.04ポイント
            
            return triggerScore + targetScore
            
        } catch {
            print("チェーン位置スコア計算エラー: \(error)")
            return 0.0
        }
    }
    
    /// 時間的パターンからスコアを算出
    private func calculateTemporalPatternScore(
        for habit: Habit,
        context: ModelContext
    ) async -> Double {
        do {
            let executions = try await getRecentExecutions(for: habit, context: context, days: 14)
            
            guard executions.count >= 3 else { return 0.0 }
            
            // 朝の実行が多い場合（ルーティンの重要性）
            let morningExecutions = executions.filter { execution in
                let hour = Calendar.current.component(.hour, from: execution.executedAt)
                return hour >= 6 && hour <= 10
            }
            let morningRatio = Double(morningExecutions.count) / Double(executions.count)
            let morningScore = morningRatio * 0.03 // 最大0.03ポイント
            
            // 週末の実行率（継続性の重要性）
            let weekendExecutions = executions.filter { execution in
                let weekday = Calendar.current.component(.weekday, from: execution.executedAt)
                return weekday == 1 || weekday == 7 // 日曜日 または 土曜日
            }
            let weekendRatio = Double(weekendExecutions.count) / Double(executions.count)
            let continuityScore = weekendRatio * 0.02 // 最大0.02ポイント
            
            return morningScore + continuityScore
            
        } catch {
            print("時間的パターンスコア計算エラー: \(error)")
            return 0.0
        }
    }
    
    /// 文脈的スコアを算出
    private func calculateContextualScore(_ params: Habit.HiddenParameters) -> Double {
        var score: Double = 0.0
        
        // 季節変動がある場合（安定性の欠如で重要度下がる）
        if params.seasonalVariation == true {
            score -= 0.02
        }
        
        // ユーザーの現実的期待が高い場合
        if let expectation = params.userRealisticExpectation {
            score += expectation * 0.03 // 最大0.03ポイント
        }
        
        // 文脈的トリガーが多い場合（環境依存度が高い）
        if let triggers = params.contextualTriggers, !triggers.isEmpty {
            score += min(Double(triggers.count) * 0.01, 0.03) // 最大0.03ポイント
        }
        
        return score
    }
    
    // MARK: - Helper Methods
    
    /// 最近の実行記録を取得
    private func getRecentExecutions(
        for habit: Habit,
        context: ModelContext,
        days: Int
    ) async throws -> [HabitExecution] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        // HabitとHabitExecutionの関係性を使用して取得
        return habit.executions.filter { execution in
            execution.executedAt >= startDate
        }.sorted { $0.executedAt > $1.executedAt }
    }
    
    /// 一貫性スコアを計算
    private func calculateConsistencyScore(_ executions: [HabitExecution]) -> Double {
        guard executions.count > 1 else { return 0.0 }
        
        // 実行間隔の標準偏差を計算
        let intervals = zip(executions.dropLast(), executions.dropFirst()).map { later, earlier in
            later.executedAt.timeIntervalSince(earlier.executedAt) / 3600 // 時間単位
        }
        
        guard intervals.count > 1 else { return 0.5 }
        
        let average = intervals.reduce(0, +) / Double(intervals.count)
        let variance = intervals.reduce(0) { sum, interval in
            sum + pow(interval - average, 2)
        } / Double(intervals.count)
        let standardDeviation = sqrt(variance)
        
        // 標準偏差が小さいほど一貫性が高い
        let normalizedStdDev = min(standardDeviation / 24.0, 1.0) // 24時間で正規化
        return 1.0 - normalizedStdDev
    }
    
    /// 習慣がトリガーとなるチェーンを取得
    private func getChainsWhereHabitIsTrigger(
        habit: Habit,
        context: ModelContext
    ) async throws -> [HabitChain] {
        let fetchDescriptor = FetchDescriptor<HabitChain>()
        let allChains = try context.fetch(fetchDescriptor)
        
        return allChains.filter { chain in
            chain.triggerHabits.contains(habit.id)
        }
    }
    
    /// 習慣がターゲットとなるチェーンを取得
    private func getChainsWhereHabitIsTarget(
        habit: Habit,
        context: ModelContext
    ) async throws -> [HabitChain] {
        let habitId = habit.id
        let fetchDescriptor = FetchDescriptor<HabitChain>(
            predicate: #Predicate<HabitChain> { chain in
                chain.nextHabitId == habitId
            }
        )
        
        return try context.fetch(fetchDescriptor)
    }
    
    // MARK: - Batch Processing
    
    /// すべての習慣の推測重要度を更新
    func updateAllInferredImportances(context: ModelContext) async {
        do {
            let fetchDescriptor = FetchDescriptor<Habit>(
                predicate: #Predicate<Habit> { habit in
                    !habit.isArchived
                }
            )
            let habits = try context.fetch(fetchDescriptor)
            
            for habit in habits {
                let inferredImportance = await calculateInferredImportance(for: habit, context: context)
                habit.importanceInferred = inferredImportance
                habit.updatedAt = Date()
            }
            
            try context.save()
            print("ImportanceInferenceService: \(habits.count)個の習慣の推測重要度を更新完了")
            
        } catch {
            print("推測重要度の一括更新エラー: \(error)")
        }
    }
}

// MARK: - Combined Importance Calculation
extension Habit {
    /// 最終的な重要度（明示的重要度と推測重要度の組み合わせ）
    func getFinalImportance() -> Double {
        let explicit = importance ?? 0.5
        let inferred = importanceInferred ?? 0.5
        
        // 明示的重要度が設定されている場合はそれを重視（70%）、推測重要度は補助（30%）
        if importance != nil {
            return explicit * 0.7 + inferred * 0.3
        } else {
            // 明示的重要度が未設定の場合は推測重要度をそのまま使用
            return inferred
        }
    }
    
    /// 重要度カテゴリを取得
    func getImportanceCategory() -> ImportanceCategory {
        let finalImportance = getFinalImportance()
        
        if finalImportance >= 0.8 {
            return .critical
        } else if finalImportance >= 0.6 {
            return .high
        } else if finalImportance >= 0.4 {
            return .medium
        } else {
            return .low
        }
    }
}

enum ImportanceCategory: String, CaseIterable {
    case critical = "重要"
    case high = "高"
    case medium = "中"
    case low = "低"
    
    var color: String {
        switch self {
        case .critical:
            return "red"
        case .high:
            return "orange"
        case .medium:
            return "yellow"
        case .low:
            return "gray"
        }
    }
    
    var priority: Int {
        switch self {
        case .critical:
            return 3
        case .high:
            return 2
        case .medium:
            return 1
        case .low:
            return 0
        }
    }
}