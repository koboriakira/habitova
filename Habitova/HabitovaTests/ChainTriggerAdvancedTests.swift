//
//  ChainTriggerAdvancedTests.swift
//  Habitova
//
//  Created by Claude on 2025/12/23.
//

import Testing
import Foundation
import SwiftData
@testable import Habitova

@Suite("チェーントリガー高度テスト")
struct ChainTriggerAdvancedTests {
    
    // MARK: - エラーハンドリングテスト
    
    @Test("空のデータベースでのエラーハンドリング")
    @MainActor
    func testEmptyDatabaseHandling() async throws {
        let container = try createTestModelContainer()
        let context = container.mainContext
        
        // 空のデータベースでトリガーメッセージを生成
        let triggerService = ChainTriggerService.shared
        let triggerMessages = await triggerService.generateTriggerMessages(
            for: [UUID()],
            context: context
        )
        
        // エラーではなく空の配列が返されることを確認
        #expect(triggerMessages.isEmpty, "空のデータベースでは空の配列が返されるべき")
        
        print("✅ 空のデータベース処理テスト成功")
    }
    
    @Test("不正なUUIDでのエラーハンドリング")
    @MainActor
    func testInvalidUUIDHandling() async throws {
        let container = try createTestModelContainer()
        let context = container.mainContext
        let (_, _) = try ChainTriggerTestHelpers.createThreeStepChainData(context: context)
        
        // 存在しないUUIDでトリガーメッセージを生成
        let nonExistentId = UUID()
        let triggerService = ChainTriggerService.shared
        let triggerMessages = await triggerService.generateTriggerMessages(
            for: [nonExistentId],
            context: context
        )
        
        // エラーではなく空の配列が返されることを確認
        #expect(triggerMessages.isEmpty, "存在しない習慣IDでは空の配列が返されるべき")
        
        print("✅ 不正なUUID処理テスト成功")
    }
    
    @Test("破損したチェーンデータでのエラーハンドリング")
    @MainActor
    func testCorruptedChainHandling() async throws {
        let container = try createTestModelContainer()
        let context = container.mainContext
        
        let habitId = UUID()
        let habit = Habit(
            name: "テスト習慣",
            habitDescription: "テスト用",
            targetFrequency: "daily"
        )
        habit.id = habitId
        context.insert(habit)
        
        // 存在しないnextHabitIdを持つ破損したチェーン
        let corruptedChain = HabitChain(
            triggerHabits: [habitId],
            prerequisiteHabits: [String: Any]?(nil),
            nextHabitId: UUID(), // 存在しないID
            delayMinutes: 5,
            triggerCondition: TriggerCondition(type: "immediate", delayMinutes: 5, context: nil),
            confidence: 0.8
        )
        context.insert(corruptedChain)
        try context.save()
        
        // トリガーメッセージを生成
        let triggerService = ChainTriggerService.shared
        let triggerMessages = await triggerService.generateTriggerMessages(
            for: [habitId],
            context: context
        )
        
        // 破損したチェーンは無視され、エラーにならないことを確認
        #expect(triggerMessages.isEmpty, "破損したチェーンは無視されるべき")
        
        print("✅ 破損したチェーンデータ処理テスト成功")
    }
    
    // MARK: - パフォーマンステスト
    
    @Test("大量データでのパフォーマンステスト")
    @MainActor
    func testLargeDataPerformance() async throws {
        let container = try createTestModelContainer()
        let context = container.mainContext
        
        // 大量の習慣とチェーンを作成
        var habits: [Habit] = []
        var chains: [HabitChain] = []
        
        for i in 0..<100 {
            let habit = Habit(
                name: "習慣\(i)",
                habitDescription: "テスト習慣\(i)",
                targetFrequency: "daily"
            )
            habits.append(habit)
            context.insert(habit)
            
            if i > 0 {
                let chain = HabitChain(
                    triggerHabits: [habits[i-1].id],
                    prerequisiteHabits: [String: Any]?(nil),
                    nextHabitId: habit.id,
                    delayMinutes: 5,
                    triggerCondition: TriggerCondition(type: "immediate", delayMinutes: 5, context: nil),
                    confidence: 0.8
                )
                chains.append(chain)
                context.insert(chain)
            }
        }
        
        try context.save()
        
        // パフォーマンステストを実行
        let averageTime = await ChainTriggerTestHelpers.measureTriggerGenerationPerformance(
            habitIds: [habits[0].id, habits[1].id, habits[2].id],
            context: context,
            iterations: 10
        )
        
        // パフォーマンス基準（1秒以下）
        #expect(averageTime < 1.0, "大量データでも1秒以下で処理されるべき（実際: \(averageTime)秒）")
        
        print("✅ 大量データパフォーマンステスト成功")
    }
    
    // MARK: - 複雑なチェーンテスト
    
    @Test("複数トリガー習慣を持つチェーンのテスト")
    @MainActor
    func testMultipleTriggerChain() async throws {
        let container = try createTestModelContainer()
        let context = container.mainContext
        
        let habit1 = Habit(name: "習慣1", habitDescription: "テスト1", targetFrequency: "daily")
        let habit2 = Habit(name: "習慣2", habitDescription: "テスト2", targetFrequency: "daily")
        let habit3 = Habit(name: "習慣3", habitDescription: "テスト3", targetFrequency: "daily")
        
        context.insert(habit1)
        context.insert(habit2)
        context.insert(habit3)
        
        // 習慣1と習慣2の両方が完了したときに習慣3がトリガーされるチェーン
        let multiTriggerChain = HabitChain(
            triggerHabits: [habit1.id, habit2.id],
            prerequisiteHabits: [String: Any]?(nil),
            nextHabitId: habit3.id,
            delayMinutes: 10,
            triggerCondition: TriggerCondition(type: "all_required", delayMinutes: 10, context: nil),
            confidence: 0.9
        )
        context.insert(multiTriggerChain)
        try context.save()
        
        // 習慣1のみ実行（習慣3はまだトリガーされない）
        let triggerService = ChainTriggerService.shared
        var triggerMessages = await triggerService.generateTriggerMessages(
            for: [habit1.id],
            context: context
        )
        
        #expect(triggerMessages.isEmpty, "単一トリガーでは複数要求チェーンは発動しないべき")
        
        // 習慣1と習慣2の両方を実行（習慣3がトリガーされる）
        triggerMessages = await triggerService.generateTriggerMessages(
            for: [habit1.id, habit2.id],
            context: context
        )
        
        #expect(!triggerMessages.isEmpty, "複数トリガーが満たされたときはチェーンが発動するべき")
        
        print("✅ 複数トリガーチェーンテスト成功")
    }
    
    @Test("分岐チェーン（一つの習慣から複数のトリガー）")
    @MainActor
    func testBranchingChain() async throws {
        let container = try createTestModelContainer()
        let context = container.mainContext
        
        let wakeupHabit = Habit(name: "起床", habitDescription: "朝起きる", targetFrequency: "daily")
        let washingHabit = Habit(name: "洗顔", habitDescription: "顔を洗う", targetFrequency: "daily")
        let stretchHabit = Habit(name: "ストレッチ", habitDescription: "軽い運動", targetFrequency: "daily")
        
        context.insert(wakeupHabit)
        context.insert(washingHabit)
        context.insert(stretchHabit)
        
        // 起床から洗顔とストレッチの両方へのチェーンを作成
        let washingChain = HabitChain(
            triggerHabits: [wakeupHabit.id],
            prerequisiteHabits: [String: Any]?(nil),
            nextHabitId: washingHabit.id,
            delayMinutes: 5,
            triggerCondition: TriggerCondition(type: "immediate", delayMinutes: 5, context: nil),
            confidence: 0.9
        )
        
        let stretchChain = HabitChain(
            triggerHabits: [wakeupHabit.id],
            prerequisiteHabits: [String: Any]?(nil),
            nextHabitId: stretchHabit.id,
            delayMinutes: 10,
            triggerCondition: TriggerCondition(type: "immediate", delayMinutes: 10, context: nil),
            confidence: 0.7
        )
        
        context.insert(washingChain)
        context.insert(stretchChain)
        try context.save()
        
        // 起床を実行
        let triggerService = ChainTriggerService.shared
        let triggerMessages = await triggerService.generateTriggerMessages(
            for: [wakeupHabit.id],
            context: context
        )
        
        // 洗顔とストレッチの両方のトリガーメッセージが生成されることを確認
        #expect(triggerMessages.count >= 2, "分岐チェーンでは複数のトリガーメッセージが生成されるべき")
        
        let hasWashingTrigger = triggerMessages.contains { $0.contains("洗顔") }
        let hasStretchTrigger = triggerMessages.contains { $0.contains("ストレッチ") }
        
        #expect(hasWashingTrigger, "洗顔トリガーが含まれるべき")
        #expect(hasStretchTrigger, "ストレッチトリガーが含まれるべき")
        
        print("✅ 分岐チェーンテスト成功")
        print("生成されたトリガーメッセージ: \(triggerMessages)")
    }
    
    // MARK: - 実際のAPI使用統合テスト
    
    @Test("実際のAPI使用 - 自然言語による複雑な報告")
    .disabled("本物のAPIを使用するため無効化")
    @MainActor
    func testRealAPIComplexInput() async throws {
        let hasAPI = ChainTriggerTestHelpers.checkAPIConfiguration()
        
        let container = try createTestModelContainer()
        let context = container.mainContext
        let (habits, _) = try ChainTriggerTestHelpers.createThreeStepChainData(context: context)
        
        let claudeService = ClaudeAPIService.shared
        
        // 複雑な自然言語入力をテスト
        let complexInputs = [
            "今朝は7時に目が覚めました。まず洗面所で顔を洗って歯を磨きました。それからコーヒーを入れて飲みました。",
            "朝のルーティンをやりました。起床、身支度、コーヒーの準備まで一通り。",
            "寝坊しちゃったけど、なんとか洗顔だけはできました。"
        ]
        
        for input in complexInputs {
            print("\n🔍 テスト入力: \(input)")
            
            let analysisResult = try await claudeService.analyzeUserInput(
                userInput: input,
                availableHabits: habits,
                conversationHistory: []
            )
            
            if hasAPI {
                // 実際のAPIを使用している場合、より厳密に検証
                #expect(!analysisResult.extractedHabits.isEmpty, "実際のAPIでは習慣が抽出されるべき")
            }
            
            // 抽出された習慣でトリガーメッセージを生成
            let executedHabitIds = analysisResult.extractedHabits.map { $0.habitId }
            if !executedHabitIds.isEmpty {
                let triggerMessages = await ChainTriggerService.shared.generateTriggerMessages(
                    for: executedHabitIds,
                    context: context
                )
                
                print("   抽出された習慣: \(analysisResult.extractedHabits.map { $0.habitName })")
                print("   トリガーメッセージ: \(triggerMessages)")
            }
        }
        
        print("✅ 実際のAPI複雑入力テスト完了")
    }
    
    @Test("APIレスポンス時間測定")
    .disabled("本物のAPIを使用するため無効化")
    @MainActor
    func testAPIResponseTime() async throws {
        let hasAPI = ChainTriggerTestHelpers.checkAPIConfiguration()
        guard hasAPI else {
            print("⏭️  APIキーが設定されていないため、レスポンス時間測定をスキップ")
            return
        }
        
        let container = try createTestModelContainer()
        let context = container.mainContext
        let (habits, _) = try ChainTriggerTestHelpers.createThreeStepChainData(context: context)
        
        let claudeService = ClaudeAPIService.shared
        let testInput = "朝起きて洗顔しました"
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let analysisResult = try await claudeService.analyzeUserInput(
            userInput: testInput,
            availableHabits: habits,
            conversationHistory: []
        )
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let responseTime = endTime - startTime
        
        print("📊 API レスポンス時間: \(String(format: "%.3f", responseTime))秒")
        print("   抽出された習慣: \(analysisResult.extractedHabits.map { $0.habitName })")
        
        // 合理的なレスポンス時間（10秒以下）
        #expect(responseTime < 10.0, "APIレスポンス時間が10秒以下であるべき（実際: \(responseTime)秒）")
        
        print("✅ APIレスポンス時間測定完了")
    }
    
    // MARK: - ヘルパーメソッド
    
    private func createTestModelContainer() throws -> ModelContainer {
        let schema = Schema([
            Habit.self,
            HabitChain.self,
            HabitExecution.self,
            Message.self
        ])
        
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}