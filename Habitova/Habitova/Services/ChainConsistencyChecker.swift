//
//  ChainConsistencyChecker.swift
//  Habitova
//
//  Created by Claude on 2025/12/21.
//

import Foundation
import SwiftData

@MainActor
class ChainConsistencyChecker {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func checkChainConsistency(for executedHabits: [UUID], on date: Date = Date()) async -> ChainConsistencyReport? {
        // 実行された習慣に関連するチェーンを検索
        let relevantChains = await findRelevantChains(for: executedHabits)
        
        guard !relevantChains.isEmpty else { 
            print("ChainConsistencyChecker: No relevant chains found for executed habits: \(executedHabits)")
            return nil 
        }
        
        // 最も関連度の高いチェーンを選択
        let primaryChain = selectPrimaryChain(from: relevantChains, executedHabits: executedHabits)
        
        guard let chain = primaryChain else {
            print("ChainConsistencyChecker: No primary chain selected")
            return nil
        }
        
        print("ChainConsistencyChecker: Analyzing chain \(chain.id) for habits: \(executedHabits)")
        
        // チェーンの整合性を分析
        return await analyzeChainConsistency(chain: chain, executedHabits: executedHabits, date: date)
    }
    
    private func findRelevantChains(for executedHabits: [UUID]) async -> [HabitChain] {
        let fetchDescriptor = FetchDescriptor<HabitChain>()
        
        do {
            let allChains = try modelContext.fetch(fetchDescriptor)
            
            // 実行された習慣を含むチェーンをフィルタリング
            return allChains.filter { chain in
                let chainHabitIds = [chain.nextHabitId] + chain.triggerHabits
                return !Set(chainHabitIds).intersection(Set(executedHabits)).isEmpty
            }
        } catch {
            print("Error fetching habit chains: \(error)")
            return []
        }
    }
    
    private func selectPrimaryChain(from chains: [HabitChain], executedHabits: [UUID]) -> HabitChain? {
        // 実行された習慣との重複数が最も多いチェーンを選択
        let chainScores = chains.map { chain in
            let chainHabitIds = [chain.nextHabitId] + chain.triggerHabits
            let overlap = Set(chainHabitIds).intersection(Set(executedHabits)).count
            return (chain: chain, score: overlap)
        }
        
        return chainScores.max(by: { $0.score < $1.score })?.chain
    }
    
    private func analyzeChainConsistency(chain: HabitChain, executedHabits: [UUID], date: Date) async -> ChainConsistencyReport {
        // チェーンの期待される順序を構築（トリガー習慣 → 次の習慣の順序）
        let triggerHabits = chain.triggerHabits
        let nextHabit = chain.nextHabitId
        let expectedSequence = triggerHabits + [nextHabit]
        
        let executedSet = Set(executedHabits)
        
        // 期待されているが実行されていない習慣
        let skippedHabits = expectedSequence.filter { !executedSet.contains($0) }
        
        // 実行されたが期待されていない習慣  
        let unexpectedHabits = executedHabits.filter { !expectedSequence.contains($0) }
        
        // 実行順序の分析
        let executionOrder = await analyzeExecutionOrder(executedHabits: executedHabits, expectedOrder: expectedSequence, date: date)
        
        // 不整合レベルの計算
        let inconsistencyLevel = calculateInconsistencyLevel(
            expectedCount: expectedSequence.count,
            executedCount: executedHabits.count,
            skippedCount: skippedHabits.count,
            unexpectedCount: unexpectedHabits.count,
            orderViolations: executionOrder.violations.count
        )
        
        // チェーン名を生成（期待順序の最初と最後の習慣から）
        let chainName = await generateChainName(for: expectedSequence)
        
        print("ChainConsistencyChecker: Analysis complete - Inconsistency: \(inconsistencyLevel), Skipped: \(skippedHabits.count), Unexpected: \(unexpectedHabits.count)")
        
        return ChainConsistencyReport(
            chainId: chain.id,
            chainName: chainName,
            expectedSequence: expectedSequence,
            executedHabits: executedHabits,
            skippedHabits: skippedHabits,
            unexpectedHabits: unexpectedHabits,
            executionOrder: executionOrder,
            inconsistencyLevel: inconsistencyLevel,
            suggestions: await generateSuggestions(skippedHabits: skippedHabits, chain: chain)
        )
    }
    
    private func analyzeExecutionOrder(executedHabits: [UUID], expectedOrder: [UUID], date: Date) async -> ExecutionOrderAnalysis {
        // 今日の実行記録を取得してタイムスタンプ順にソート
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let fetchDescriptor = FetchDescriptor<HabitExecution>(
            predicate: #Predicate<HabitExecution> { execution in
                execution.executedAt >= startOfDay && execution.executedAt < endOfDay
            },
            sortBy: [SortDescriptor(\.executedAt)]
        )
        
        do {
            let executions = try modelContext.fetch(fetchDescriptor)
            let executionTimeMap: [UUID: Date] = Dictionary(uniqueKeysWithValues: executions.compactMap { execution in
                guard let habitId = execution.habit?.id else { return nil }
                return (habitId, execution.executedAt)
            })
            
            // 実行順序の違反を検出
            var violations: [OrderViolation] = []
            let executedInExpectedOrder = executedHabits.filter { expectedOrder.contains($0) }
            
            for i in 0..<executedInExpectedOrder.count {
                for j in (i+1)..<executedInExpectedOrder.count {
                    let habitA = executedInExpectedOrder[i]
                    let habitB = executedInExpectedOrder[j]
                    
                    guard let indexA = expectedOrder.firstIndex(of: habitA),
                          let indexB = expectedOrder.firstIndex(of: habitB),
                          let timeA = executionTimeMap[habitA],
                          let timeB = executionTimeMap[habitB] else { continue }
                    
                    // 期待される順序とは逆に実行された場合
                    if indexA < indexB && timeA > timeB {
                        violations.append(OrderViolation(
                            expectedFirst: habitA,
                            expectedSecond: habitB,
                            actualOrder: .reversed
                        ))
                    }
                }
            }
            
            return ExecutionOrderAnalysis(
                correctOrder: violations.isEmpty,
                violations: violations,
                executionTimes: executionTimeMap
            )
            
        } catch {
            print("Error analyzing execution order: \(error)")
            return ExecutionOrderAnalysis(correctOrder: true, violations: [], executionTimes: [:])
        }
    }
    
    private func calculateInconsistencyLevel(
        expectedCount: Int,
        executedCount: Int,
        skippedCount: Int,
        unexpectedCount: Int,
        orderViolations: Int
    ) -> Double {
        guard expectedCount > 0 else { return 0.0 }
        
        let skippedPenalty = Double(skippedCount) / Double(expectedCount) * 0.4
        let unexpectedPenalty = Double(unexpectedCount) / Double(expectedCount) * 0.3
        let orderPenalty = Double(orderViolations) / Double(expectedCount) * 0.3
        
        return min(1.0, skippedPenalty + unexpectedPenalty + orderPenalty)
    }
    
    /// チェーン名を生成
    private func generateChainName(for expectedSequence: [UUID]) async -> String {
        do {
            let fetchDescriptor = FetchDescriptor<Habit>(predicate: #Predicate<Habit> { habit in
                expectedSequence.contains(habit.id)
            })
            let habits = try modelContext.fetch(fetchDescriptor)
            
            if let firstHabit = habits.first(where: { $0.id == expectedSequence.first }),
               let lastHabit = habits.first(where: { $0.id == expectedSequence.last }) {
                return "\(firstHabit.name) → \(lastHabit.name)"
            }
        } catch {
            print("Error generating chain name: \(error)")
        }
        return "習慣チェーン"
    }
    
    private func generateSuggestions(skippedHabits: [UUID], chain: HabitChain) async -> [String] {
        guard !skippedHabits.isEmpty else { return [] }
        
        var suggestions: [String] = []
        
        // スキップされた習慣の名前を取得
        let fetchDescriptor = FetchDescriptor<Habit>(
            predicate: #Predicate<Habit> { habit in
                skippedHabits.contains(habit.id)
            }
        )
        
        do {
            let skippedHabitsData = try modelContext.fetch(fetchDescriptor)
            let habitNames = skippedHabitsData.map { $0.name }
            
            if habitNames.count == 1 {
                suggestions.append("「\(habitNames.first!)」もお忘れなく！")
            } else if habitNames.count <= 3 {
                suggestions.append("「\(habitNames.joined(separator: "」と「"))」もお忘れなく！")
            } else {
                suggestions.append("\(habitNames.count)個の習慣がまだ完了していません")
            }
            
            // チェーン特有のアドバイス（隠れパラメータを考慮）
            let triggerHabits = chain.triggerHabits
            let nextHabitId = chain.nextHabitId
            
            // トリガー習慣が実行済みで、次の習慣がスキップされている場合
            let triggerExecuted = triggerHabits.allSatisfy { !skippedHabits.contains($0) }
            let nextSkipped = skippedHabits.contains(nextHabitId)
            
            if triggerExecuted && nextSkipped {
                if let nextHabitName = skippedHabitsData.first(where: { $0.id == nextHabitId })?.name {
                    suggestions.append("今が「\(nextHabitName)」を実行する良いタイミングです")
                }
            } else if !triggerExecuted {
                suggestions.append("習慣の連続を完成させましょう")
            }
            
        } catch {
            suggestions.append("いくつかの習慣がまだ完了していません")
        }
        
        return suggestions
    }
}

// MARK: - データ構造

struct ChainConsistencyReport: Sendable {
    let chainId: UUID
    let chainName: String
    let expectedSequence: [UUID]
    let executedHabits: [UUID]
    let skippedHabits: [UUID]
    let unexpectedHabits: [UUID]
    let executionOrder: ExecutionOrderAnalysis
    let inconsistencyLevel: Double
    let suggestions: [String]
}

struct ExecutionOrderAnalysis: Sendable {
    let correctOrder: Bool
    let violations: [OrderViolation]
    let executionTimes: [UUID: Date]
}

struct OrderViolation: Sendable {
    let expectedFirst: UUID
    let expectedSecond: UUID
    let actualOrder: ViolationType
    
    enum ViolationType: String, Sendable {
        case reversed = "reversed"
        case simultaneous = "simultaneous"
    }
}