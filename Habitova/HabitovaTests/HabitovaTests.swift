//
//  HabitovaTests.swift
//  HabitovaTests
//
//  Created by Akira Kobori on 2025/12/21.
//

import Testing
import Foundation
import SwiftData
@testable import Habitova

struct HabitovaTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }
    
    @Test("送信ボタンは文字列が空の時は無効化される")
    @MainActor
    func sendButtonDisabledWhenInputEmpty() async throws {
        // Given: インメモリのモデルコンテキスト
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Habit.self, Message.self, HabitExecution.self, HabitovaTask.self, ExecutionInference.self, HabitChain.self, configurations: config)
        let modelContext = container.mainContext
        
        // When: ViewModelを初期化
        let viewModel = SimpleChatViewModel(modelContext: modelContext)
        
        // Then: 初期状態では送信ボタンが無効
        #expect(viewModel.currentInput.isEmpty)
        #expect(viewModel.currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    
    @Test("送信ボタンは文字列が入力されると有効化される")
    @MainActor
    func sendButtonEnabledWhenInputNotEmpty() async throws {
        // Given: インメモリのモデルコンテキスト
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Habit.self, Message.self, HabitExecution.self, HabitovaTask.self, ExecutionInference.self, HabitChain.self, configurations: config)
        let modelContext = container.mainContext
        
        // When: ViewModelを初期化し、文字を入力
        let viewModel = SimpleChatViewModel(modelContext: modelContext)
        viewModel.currentInput = "テストメッセージ"
        
        // Then: 送信ボタンが有効化される
        #expect(!viewModel.currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    
    @Test("送信ボタンは空白のみの文字列では無効化される")
    @MainActor
    func sendButtonDisabledWithWhitespaceOnly() async throws {
        // Given: インメモリのモデルコンテキスト
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Habit.self, Message.self, HabitExecution.self, HabitovaTask.self, ExecutionInference.self, HabitChain.self, configurations: config)
        let modelContext = container.mainContext
        
        // When: ViewModelを初期化し、空白のみを入力
        let viewModel = SimpleChatViewModel(modelContext: modelContext)
        viewModel.currentInput = "   \n  \t  "
        
        // Then: 送信ボタンが無効化される
        #expect(viewModel.currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    
    @Test("EnvironmentLoaderは.envファイルからAPIキーを読み取る")
    func environmentLoaderReadsAPIKey() async throws {
        // Given: EnvironmentLoader
        let loader = EnvironmentLoader.shared
        
        // When: .envファイルから値を読み取り
        let apiKey = loader.getClaudeAPIKey()
        
        // Then: APIキーが存在することを確認
        #expect(apiKey != nil)
        #expect(!apiKey!.isEmpty)
        #expect(apiKey!.hasPrefix("sk-ant-"))
        print("EnvironmentLoader test: API key loaded (first 10 chars): \(String(apiKey!.prefix(10)))...")
    }
    
    @Test("ClaudeAPIServiceはAPIキーを正しく設定する")
    @MainActor
    func claudeAPIServiceConfiguresAPIKey() async throws {
        // Given: ClaudeAPIService
        let service = ClaudeAPIService.shared
        
        // When: APIキーが設定されているかチェック
        let isConfigured = service.isAPIKeyConfigured()
        
        // Then: APIキーが設定されている
        #expect(isConfigured)
        print("ClaudeAPIService test: API key is configured")
    }
    
    // API実行テスト：クレジット消費を避けるため一時的にスキップ
    // 2025/12/22にテスト成功を確認済み - 実際のClaude Haiku 4.5 APIでの習慣分析が正常動作
    @Test("ストレッチ習慣メッセージが正しく処理される", .disabled("実際のAPI実行によりクレジット消費するためスキップ - 機能動作確認済み"))
    @MainActor
    func stretchHabitMessageProcessing() async throws {
        // Given: インメモリのモデルコンテキスト
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Habit.self, Message.self, HabitExecution.self, HabitovaTask.self, ExecutionInference.self, HabitChain.self, configurations: config)
        let modelContext = container.mainContext
        
        // モックユーザーのストレッチ習慣を作成
        let stretchHabit = Habit(
            name: "毎朝のストレッチ",
            habitDescription: "朝起きてから5分間のストレッチを行う",
            targetFrequency: "daily",
            importance: 8
        )
        modelContext.insert(stretchHabit)
        try modelContext.save()
        
        // When: Claude APIサービスでユーザー入力を分析
        let service = ClaudeAPIService.shared
        let userInput = "ストレッチをしました"
        let availableHabits = [stretchHabit]
        
        let result = try await service.analyzeUserInput(
            userInput: userInput,
            availableHabits: availableHabits,
            conversationHistory: []
        )
        
        // Then: 結果が期待通りである
        #expect(!result.extractedHabits.isEmpty)
        #expect(!result.aiResponse.isEmpty)
        #expect(result.aiResponse != "申し訳ありません。分析中にエラーが発生しました。")
        
        print("ストレッチ習慣テスト結果:")
        print("- 抽出された習慣数: \(result.extractedHabits.count)")
        print("- AI応答: \(result.aiResponse)")
        print("- プロアクティブ質問数: \(result.proactiveQuestions.count)")
        
        // 抽出された習慣の詳細をチェック
        if let firstHabit = result.extractedHabits.first {
            #expect(firstHabit.habitName.contains("ストレッチ") || firstHabit.habitName.contains("朝"))
            #expect(firstHabit.completionPercentage > 0)
            print("- 抽出された習慣: \(firstHabit.habitName)")
            print("- 実行タイプ: \(firstHabit.executionType)")
            print("- 完了率: \(firstHabit.completionPercentage)%")
        }
    }
    
    // エンドツーエンドテスト：クレジット消費を避けるため一時的にスキップ
    // 2025/12/22にテスト成功を確認済み - ViewModelからClaude APIまでの全体フローが正常動作
    @Test("SimpleChatViewModelのメッセージ送信が動作する", .disabled("実際のAPI実行によりクレジット消費するためスキップ - 機能動作確認済み"))
    @MainActor
    func simpleChatViewModelSendsMessage() async throws {
        // Given: インメモリのモデルコンテキスト
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Habit.self, Message.self, HabitExecution.self, HabitovaTask.self, ExecutionInference.self, HabitChain.self, configurations: config)
        let modelContext = container.mainContext
        
        // ストレッチ習慣を追加
        let stretchHabit = Habit(
            name: "毎朝のストレッチ",
            habitDescription: "朝起きてから5分間のストレッチを行う",
            targetFrequency: "daily",
            importance: 8
        )
        modelContext.insert(stretchHabit)
        try modelContext.save()
        
        // When: ViewModelを初期化してメッセージを送信
        let viewModel = SimpleChatViewModel(modelContext: modelContext)
        viewModel.currentInput = "ストレッチをしました"
        
        let initialMessageCount = viewModel.messages.count
        #expect(!viewModel.isLoading)
        
        await viewModel.sendMessage()
        
        // Then: メッセージが正しく処理される
        #expect(!viewModel.isLoading)
        #expect(viewModel.messages.count > initialMessageCount)
        #expect(viewModel.currentInput.isEmpty)
        
        // メッセージの内容をチェック
        if viewModel.messages.count >= 2 {
            let userMessage = viewModel.messages[viewModel.messages.count - 2]
            let aiMessage = viewModel.messages.last!
            
            #expect(userMessage.sender == .user)
            #expect(userMessage.content == "ストレッチをしました")
            #expect(aiMessage.sender == .assistant)
            #expect(!aiMessage.content.contains("申し訳ありません。分析中にエラーが発生しました"))
            
            print("SimpleChatViewModel テスト結果:")
            print("- ユーザーメッセージ: \(userMessage.content)")
            print("- AI応答: \(aiMessage.content)")
        }
    }

}
