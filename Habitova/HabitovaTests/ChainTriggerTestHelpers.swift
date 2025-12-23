//
//  ChainTriggerTestHelpers.swift
//  Habitova
//
//  Created by Claude on 2025/12/23.
//

import Foundation
import SwiftData
@testable import Habitova

/// チェーントリガーテスト用のヘルパーメソッド
@MainActor
struct ChainTriggerTestHelpers {
    
    // MARK: - テストデータ作成
    
    /// 3連続チェーン用の標準テストデータを作成
    static func createThreeStepChainData(context: ModelContext) throws -> (habits: [Habit], chains: [HabitChain]) {
        let wakeupId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let washingId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let coffeeId = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        
        let habits = [
            createTestHabit(
                id: wakeupId,
                name: "朝7時起床",
                description: "7時に起床する",
                keywords: ["起床", "起き", "目覚"]
            ),
            createTestHabit(
                id: washingId,
                name: "洗顔・身だしなみ",
                description: "顔を洗い、身支度を整える",
                keywords: ["洗顔", "身だしなみ", "顔洗"]
            ),
            createTestHabit(
                id: coffeeId,
                name: "コーヒーボタンON",
                description: "コーヒーメーカーのボタンを押す",
                keywords: ["コーヒー"]
            )
        ]
        
        let chains = [
            createTestChain(triggerIds: [wakeupId], nextId: washingId, delay: 5, confidence: 0.9),
            createTestChain(triggerIds: [washingId], nextId: coffeeId, delay: 10, confidence: 0.8)
        ]
        
        // データベースに挿入
        for habit in habits {
            context.insert(habit)
        }
        for chain in chains {
            context.insert(chain)
        }
        
        try context.save()
        return (habits: habits, chains: chains)
    }
    
    /// 複雑なチェーン（分岐・合流）用のテストデータを作成
    static func createComplexChainData(context: ModelContext) throws -> (habits: [Habit], chains: [HabitChain]) {
        let habitIds = (1...6).map { _ in UUID() }
        
        let habits = [
            createTestHabit(id: habitIds[0], name: "起床", description: "朝起きる"),
            createTestHabit(id: habitIds[1], name: "洗顔", description: "顔を洗う"),
            createTestHabit(id: habitIds[2], name: "歯磨き", description: "歯を磨く"),
            createTestHabit(id: habitIds[3], name: "着替え", description: "服を着替える"),
            createTestHabit(id: habitIds[4], name: "朝食準備", description: "朝食を準備する"),
            createTestHabit(id: habitIds[5], name: "朝食", description: "朝食を食べる")
        ]
        
        let chains = [
            createTestChain(triggerIds: [habitIds[0]], nextId: habitIds[1], delay: 5, confidence: 0.9),
            createTestChain(triggerIds: [habitIds[0]], nextId: habitIds[2], delay: 5, confidence: 0.8),
            createTestChain(triggerIds: [habitIds[1]], nextId: habitIds[3], delay: 10, confidence: 0.7),
            createTestChain(triggerIds: [habitIds[2]], nextId: habitIds[3], delay: 10, confidence: 0.7),
            createTestChain(triggerIds: [habitIds[3]], nextId: habitIds[4], delay: 15, confidence: 0.8),
            createTestChain(triggerIds: [habitIds[4]], nextId: habitIds[5], delay: 5, confidence: 0.95)
        ]
        
        for habit in habits {
            context.insert(habit)
        }
        for chain in chains {
            context.insert(chain)
        }
        
        try context.save()
        return (habits: habits, chains: chains)
    }
    
    // MARK: - プライベートヘルパー
    
    private static func createTestHabit(
        id: UUID,
        name: String,
        description: String,
        keywords: [String] = [],
        importance: Double = 0.5
    ) -> Habit {
        let habit = Habit(
            name: name,
            habitDescription: description,
            targetFrequency: "daily",
            importance: importance
        )
        habit.id = id
        return habit
    }
    
    private static func createTestChain(
        triggerIds: [UUID],
        nextId: UUID,
        delay: Int,
        confidence: Double
    ) -> HabitChain {
        return HabitChain(
            triggerHabits: triggerIds,
            prerequisiteHabits: [String: Any]?(nil),
            nextHabitId: nextId,
            delayMinutes: delay,
            triggerCondition: TriggerCondition(type: "immediate", delayMinutes: delay, context: nil),
            confidence: confidence
        )
    }
    
    // MARK: - API設定確認
    
    /// 実際のClaude APIを使用する前に設定を確認
    static func checkAPIConfiguration() -> Bool {
        let claudeService = ClaudeAPIService.shared
        let isConfigured = claudeService.isAPIKeyConfigured()
        
        if !isConfigured {
            print("⚠️  Claude APIキーが設定されていません")
            print("   Keychain、.envファイル、または環境変数 CLAUDE_API_KEY を設定してください")
            print("   APIキーなしでもモックレスポンスでテストは実行されます")
        } else {
            print("✅ Claude APIキーが設定されています")
        }
        
        return isConfigured
    }
    
    // MARK: - テスト結果検証
    
    /// トリガーメッセージの内容を検証
    static func validateTriggerMessages(
        _ messages: [String],
        expectedHabitNames: [String],
        description: String
    ) -> Bool {
        guard !messages.isEmpty else {
            print("❌ \(description): トリガーメッセージが生成されませんでした")
            return false
        }
        
        var foundExpectedHabits = 0
        for expectedName in expectedHabitNames {
            let found = messages.contains { message in
                message.lowercased().contains(expectedName.lowercased())
            }
            if found {
                foundExpectedHabits += 1
            }
        }
        
        let isValid = foundExpectedHabits > 0
        if isValid {
            print("✅ \(description): 期待される習慣のトリガーメッセージが見つかりました")
            print("   生成されたメッセージ: \(messages)")
        } else {
            print("❌ \(description): 期待される習慣 \(expectedHabitNames) が見つかりませんでした")
            print("   実際のメッセージ: \(messages)")
        }
        
        return isValid
    }
    
    /// Claude API分析結果の検証
    static func validateAnalysisResult(
        _ result: HabitAnalysisResult,
        expectedHabitNames: [String],
        userInput: String
    ) -> Bool {
        guard !result.extractedHabits.isEmpty else {
            print("❌ 入力「\(userInput)」から習慣が抽出されませんでした")
            return false
        }
        
        let extractedNames = result.extractedHabits.map { $0.habitName }
        var foundExpected = false
        
        for expectedName in expectedHabitNames {
            let found = extractedNames.contains { extractedName in
                extractedName.lowercased().contains(expectedName.lowercased()) ||
                expectedName.lowercased().contains(extractedName.lowercased())
            }
            if found {
                foundExpected = true
                break
            }
        }
        
        if foundExpected {
            print("✅ 入力「\(userInput)」から期待される習慣が抽出されました")
            print("   抽出された習慣: \(extractedNames)")
        } else {
            print("⚠️  入力「\(userInput)」から期待される習慣 \(expectedHabitNames) が抽出されませんでした")
            print("   実際に抽出された習慣: \(extractedNames)")
            print("   AI応答: \(result.aiResponse)")
        }
        
        return foundExpected
    }
    
    // MARK: - パフォーマンステスト
    
    /// チェーントリガー生成のパフォーマンスを測定
    static func measureTriggerGenerationPerformance(
        habitIds: [UUID],
        context: ModelContext,
        iterations: Int = 10
    ) async -> TimeInterval {
        let triggerService = ChainTriggerService.shared
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<iterations {
            _ = await triggerService.generateTriggerMessages(for: habitIds, context: context)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime
        let averageTime = totalTime / Double(iterations)
        
        print("📊 トリガー生成パフォーマンス:")
        print("   反復回数: \(iterations)")
        print("   総時間: \(String(format: "%.3f", totalTime))秒")
        print("   平均時間: \(String(format: "%.3f", averageTime))秒")
        
        return averageTime
    }
}