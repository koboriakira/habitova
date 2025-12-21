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

}
