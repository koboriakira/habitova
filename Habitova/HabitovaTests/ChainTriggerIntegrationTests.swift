//
//  ChainTriggerIntegrationTests.swift
//  Habitova
//
//  Created by Claude on 2025/12/23.
//

import Testing
import Foundation
import SwiftData
@testable import Habitova

@Suite("チェーントリガー統合テスト")
struct ChainTriggerIntegrationTests {
    
    // MARK: - テスト用データ
    
    private let wakeupHabitId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let washingHabitId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private let coffeeHabitId = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    
    // MARK: - セットアップ
    
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
    
    @MainActor
    private func setupTestData(context: ModelContext) throws {
        // 1. 3つの習慣を作成
        let wakeupHabit = Habit(
            name: "朝7時起床",
            habitDescription: "7時に起床する",
            targetFrequency: "daily",
            importance: 0.8
        )
        wakeupHabit.id = wakeupHabitId
        
        let washingHabit = Habit(
            name: "洗顔・身だしなみ",
            habitDescription: "顔を洗い、身支度を整える",
            targetFrequency: "daily",
            importance: 0.6
        )
        washingHabit.id = washingHabitId
        
        let coffeeHabit = Habit(
            name: "コーヒーボタンON",
            habitDescription: "コーヒーメーカーのボタンを押す",
            targetFrequency: "daily",
            importance: 0.5
        )
        coffeeHabit.id = coffeeHabitId
        
        context.insert(wakeupHabit)
        context.insert(washingHabit)
        context.insert(coffeeHabit)
        
        // 2. 2つのチェーンを作成（起床→洗顔→コーヒー）
        let wakeupToWashingChain = HabitChain(
            triggerHabits: [wakeupHabitId],
            prerequisiteHabits: [String: Any]?(nil),
            nextHabitId: washingHabitId,
            delayMinutes: 5,
            triggerCondition: TriggerCondition(type: "immediate", delayMinutes: 5, context: nil),
            confidence: 0.9
        )
        
        let washingToCoffeeChain = HabitChain(
            triggerHabits: [washingHabitId],
            prerequisiteHabits: [String: Any]?(nil),
            nextHabitId: coffeeHabitId,
            delayMinutes: 10,
            triggerCondition: TriggerCondition(type: "immediate", delayMinutes: 10, context: nil),
            confidence: 0.8
        )
        
        context.insert(wakeupToWashingChain)
        context.insert(washingToCoffeeChain)
        
        try context.save()
    }
    
    // MARK: - テストケース
    
    @Test("起床報告でトリガーメッセージが生成される")
    @MainActor
    func testWakeupTriggersWashing() async throws {
        let container = try createTestModelContainer()
        let context = container.mainContext
        try setupTestData(context: context)
        
        // 起床習慣のみを実行済みとして設定
        let executedHabitIds = [wakeupHabitId]
        
        // ChainTriggerServiceでトリガーメッセージを生成
        let triggerService = ChainTriggerService.shared
        let triggerMessages = await triggerService.generateTriggerMessages(
            for: executedHabitIds,
            context: context
        )
        
        // 検証
        #expect(!triggerMessages.isEmpty, "洗顔のトリガーメッセージが生成されるべき")
        
        let hasWashingTrigger = triggerMessages.contains { message in
            message.contains("洗顔") || message.contains("身だしなみ")
        }
        #expect(hasWashingTrigger, "洗顔に関するトリガーメッセージが含まれるべき")
        
        print("✅ 起床→洗顔トリガーテスト成功")
        print("生成されたトリガーメッセージ: \(triggerMessages)")
    }
    
    @Test("洗顔報告でトリガーメッセージが生成される")
    @MainActor
    func testWashingTriggersCoffee() async throws {
        let container = try createTestModelContainer()
        let context = container.mainContext
        try setupTestData(context: context)
        
        // 洗顔習慣のみを実行済みとして設定
        let executedHabitIds = [washingHabitId]
        
        // ChainTriggerServiceでトリガーメッセージを生成
        let triggerService = ChainTriggerService.shared
        let triggerMessages = await triggerService.generateTriggerMessages(
            for: executedHabitIds,
            context: context
        )
        
        // 検証
        #expect(!triggerMessages.isEmpty, "コーヒーのトリガーメッセージが生成されるべき")
        
        let hasCoffeeTrigger = triggerMessages.contains { message in
            message.contains("コーヒー")
        }
        #expect(hasCoffeeTrigger, "コーヒーに関するトリガーメッセージが含まれるべき")
        
        print("✅ 洗顔→コーヒートリガーテスト成功")
        print("生成されたトリガーメッセージ: \(triggerMessages)")
    }
    
    @Test("3連続チェーンの完全実行テスト")
    @MainActor
    func testThreeStepChainExecution() async throws {
        let container = try createTestModelContainer()
        let context = container.mainContext
        try setupTestData(context: context)
        
        // Step 1: 起床を実行
        var executedHabitIds = [wakeupHabitId]
        var triggerMessages = await ChainTriggerService.shared.generateTriggerMessages(
            for: executedHabitIds,
            context: context
        )
        
        #expect(!triggerMessages.isEmpty, "起床後に洗顔トリガーが生成されるべき")
        let hasWashingTrigger = triggerMessages.contains { $0.contains("洗顔") || $0.contains("身だしなみ") }
        #expect(hasWashingTrigger)
        
        // Step 2: 洗顔を実行
        executedHabitIds = [washingHabitId]
        triggerMessages = await ChainTriggerService.shared.generateTriggerMessages(
            for: executedHabitIds,
            context: context
        )
        
        #expect(!triggerMessages.isEmpty, "洗顔後にコーヒートリガーが生成されるべき")
        let hasCoffeeTrigger = triggerMessages.contains { $0.contains("コーヒー") }
        #expect(hasCoffeeTrigger)
        
        // Step 3: コーヒーを実行（これ以上のトリガーはなし）
        executedHabitIds = [coffeeHabitId]
        triggerMessages = await ChainTriggerService.shared.generateTriggerMessages(
            for: executedHabitIds,
            context: context
        )
        
        // コーヒー後は追加のトリガーがないことを確認
        #expect(triggerMessages.isEmpty, "コーヒー後は追加トリガーがないべき")
        
        print("✅ 3連続チェーン完全実行テスト成功")
    }
    
    @Test("Claude API統合テスト - 起床報告")
    .disabled("本物のAPIを使用するため無効化")
    @MainActor
    func testClaudeAPIWakeupIntegration() async throws {
        let container = try createTestModelContainer()
        let context = container.mainContext
        try setupTestData(context: context)
        
        // 利用可能な習慣を取得
        let fetchDescriptor = FetchDescriptor<Habit>()
        let habits = try context.fetch(fetchDescriptor)
        
        // Claude APIサービスを使用して「起きました」を分析
        let claudeService = ClaudeAPIService.shared
        let analysisResult = try await claudeService.analyzeUserInput(
            userInput: "起きました",
            availableHabits: habits,
            conversationHistory: []
        )
        
        // 起床習慣が正しく抽出されることを確認
        #expect(!analysisResult.extractedHabits.isEmpty, "起床習慣が抽出されるべき")
        
        let hasWakeupHabit = analysisResult.extractedHabits.contains { habit in
            habit.habitId == wakeupHabitId || habit.habitName.contains("起床")
        }
        #expect(hasWakeupHabit, "起床習慣が正しく認識されるべき")
        
        // 抽出された習慣IDでトリガーメッセージを生成
        let executedHabitIds = analysisResult.extractedHabits.map { $0.habitId }
        let triggerMessages = await ChainTriggerService.shared.generateTriggerMessages(
            for: executedHabitIds,
            context: context
        )
        
        if !triggerMessages.isEmpty {
            let hasWashingTrigger = triggerMessages.contains { $0.contains("洗顔") || $0.contains("身だしなみ") }
            #expect(hasWashingTrigger, "洗顔トリガーメッセージが生成されるべき")
        }
        
        print("✅ Claude API統合テスト（起床）成功")
        print("抽出された習慣: \(analysisResult.extractedHabits.map { $0.habitName })")
        print("生成されたトリガーメッセージ: \(triggerMessages)")
    }
    
    @Test("Claude API統合テスト - 洗顔報告")
    .disabled("本物のAPIを使用するため無効化")
    @MainActor
    func testClaudeAPIWashingIntegration() async throws {
        let container = try createTestModelContainer()
        let context = container.mainContext
        try setupTestData(context: context)
        
        // 利用可能な習慣を取得
        let fetchDescriptor = FetchDescriptor<Habit>()
        let habits = try context.fetch(fetchDescriptor)
        
        // Claude APIサービスを使用して「洗顔しました」を分析
        let claudeService = ClaudeAPIService.shared
        let analysisResult = try await claudeService.analyzeUserInput(
            userInput: "洗顔しました",
            availableHabits: habits,
            conversationHistory: []
        )
        
        // 洗顔習慣が正しく抽出されることを確認
        #expect(!analysisResult.extractedHabits.isEmpty, "洗顔習慣が抽出されるべき")
        
        let hasWashingHabit = analysisResult.extractedHabits.contains { habit in
            habit.habitId == washingHabitId || habit.habitName.contains("洗顔")
        }
        #expect(hasWashingHabit, "洗顔習慣が正しく認識されるべき")
        
        // 抽出された習慣IDでトリガーメッセージを生成
        let executedHabitIds = analysisResult.extractedHabits.map { $0.habitId }
        let triggerMessages = await ChainTriggerService.shared.generateTriggerMessages(
            for: executedHabitIds,
            context: context
        )
        
        if !triggerMessages.isEmpty {
            let hasCoffeeTrigger = triggerMessages.contains { $0.contains("コーヒー") }
            #expect(hasCoffeeTrigger, "コーヒートリガーメッセージが生成されるべき")
        }
        
        print("✅ Claude API統合テスト（洗顔）成功")
        print("抽出された習慣: \(analysisResult.extractedHabits.map { $0.habitName })")
        print("生成されたトリガーメッセージ: \(triggerMessages)")
    }
    
    @Test("エンドツーエンド統合テスト - SimpleChatViewModel")
    .disabled("本物のAPIを使用するため無効化")
    @MainActor
    func testEndToEndChatViewModelIntegration() async throws {
        let container = try createTestModelContainer()
        let context = container.mainContext
        try setupTestData(context: context)
        
        // SimpleChatViewModelを作成
        let chatViewModel = SimpleChatViewModel(modelContext: context)
        
        // 「起きました」メッセージを送信
        chatViewModel.currentInput = "起きました"
        await chatViewModel.sendMessage()
        
        // メッセージが追加されていることを確認
        #expect(chatViewModel.messages.count >= 2, "ユーザーメッセージとAI応答が追加されるべき")
        
        let lastMessage = chatViewModel.messages.last
        #expect(lastMessage?.sender == .assistant, "最後のメッセージはAI応答であるべき")
        
        // AI応答にトリガーメッセージが含まれているかチェック
        if let content = lastMessage?.content {
            let hasWashingTrigger = content.contains("洗顔") || content.contains("身だしなみ")
            #expect(hasWashingTrigger, "AI応答に洗顔トリガーが含まれるべき")
        }
        
        print("✅ エンドツーエンド統合テスト成功")
        print("最終AI応答: \(lastMessage?.content ?? "")")
    }
    
    @Test("チェーン整合性チェックテスト")
    @MainActor
    func testChainConsistencyCheck() async throws {
        let container = try createTestModelContainer()
        let context = container.mainContext
        try setupTestData(context: context)
        
        let chainChecker = ChainConsistencyChecker(modelContext: context)
        
        // Test 1: 正常なチェーン実行（順番通り）
        var report = await chainChecker.checkChainConsistency(for: [wakeupHabitId])
        #expect(report != nil, "チェーン整合性レポートが生成されるべき")
        
        // Test 2: スキップされた習慣の検出
        report = await chainChecker.checkChainConsistency(for: [coffeeHabitId]) // 洗顔をスキップ
        if let report = report {
            #expect(!report.suggestions.isEmpty, "スキップに対する提案が生成されるべき")
        }
        
        print("✅ チェーン整合性チェックテスト成功")
    }
}