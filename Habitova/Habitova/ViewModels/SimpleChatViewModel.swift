//
//  SimpleChatViewModel.swift
//  Habitova
//
//  Created by Claude on 2025/12/21.
//

import Foundation
import SwiftData
import Combine

@MainActor
class SimpleChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var currentInput: String = ""
    @Published var isLoading: Bool = false
    @Published var lastChainReport: ChainConsistencyReport?
    
    private let modelContext: ModelContext
    private let claudeAPIService: ClaudeAPIService
    private let chainChecker: ChainConsistencyChecker
    private let conversationId = UUID()
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.claudeAPIService = ClaudeAPIService.shared
        self.chainChecker = ChainConsistencyChecker(modelContext: modelContext)
        loadRecentMessages()
    }
    
    func sendMessage() async {
        print("SimpleChatViewModel: sendMessage() called")
        guard !currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("SimpleChatViewModel: currentInput is empty, returning")
            return
        }
        print("SimpleChatViewModel: processing message: \(currentInput)")
        
        let userMessageContent = currentInput
        currentInput = ""
        isLoading = true
        
        // ユーザーメッセージを保存
        let userMessage = Message(
            conversationId: conversationId,
            sender: .user,
            content: userMessageContent
        )
        modelContext.insert(userMessage)
        messages.append(userMessage)
        
        // 利用可能な習慣を取得
        let availableHabits = await getAvailableHabits()
        
        do {
            // Claude APIで習慣分析を実行
            let analysisResult = try await claudeAPIService.analyzeUserInput(
                userInput: userMessageContent,
                availableHabits: availableHabits,
                conversationHistory: messages.suffix(5).map { $0 }
            )
            
            // 抽出された習慣の実行記録を保存
            await saveHabitExecutions(analysisResult.extractedHabits)
            
            // チェーン整合性をチェック
            let executedHabitIds = analysisResult.extractedHabits.map { $0.habitId }
            lastChainReport = await chainChecker.checkChainConsistency(for: executedHabitIds)
            
            // チェーン整合性の結果をAI応答に追加
            var enhancedResponse = analysisResult.aiResponse
            if let report = lastChainReport, !report.suggestions.isEmpty {
                enhancedResponse += "\n\n💡 " + report.suggestions.joined(separator: "\n💡 ")
            }
            
            // AI応答を作成
            let aiMessage = Message(
                conversationId: conversationId,
                sender: .assistant,
                content: enhancedResponse
            )
            
            modelContext.insert(aiMessage)
            messages.append(aiMessage)
            
        } catch {
            print("Claude API Error: \(error)")
            
            // エラー時のフォールバック応答
            let errorMessage = Message(
                conversationId: conversationId,
                sender: .assistant,
                content: "申し訳ありません。分析中にエラーが発生しました。\nあなたのメッセージ: \(userMessageContent)"
            )
            
            modelContext.insert(errorMessage)
            messages.append(errorMessage)
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving: \(error)")
        }
        
        isLoading = false
    }
    
    private func getAvailableHabits() async -> [Habit] {
        let fetchDescriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.name)]
        )
        
        do {
            return try modelContext.fetch(fetchDescriptor)
        } catch {
            print("Error fetching habits: \(error)")
            return []
        }
    }
    
    private func saveHabitExecutions(_ inferredHabits: [InferredHabit]) async {
        for inferredHabit in inferredHabits {
            // 該当する習慣を検索
            let fetchDescriptor = FetchDescriptor<Habit>(
                predicate: #Predicate<Habit> { $0.id == inferredHabit.habitId }
            )
            
            guard let habit = try? modelContext.fetch(fetchDescriptor).first else {
                continue
            }
            
            // 習慣実行記録を作成
            let execution = HabitExecution(
                habit: habit,
                message: messages.last,
                executionType: inferredHabit.executionType,
                completionPercentage: inferredHabit.completionPercentage,
                executedAt: Date()
            )
            
            modelContext.insert(execution)
        }
    }
    
    private func loadRecentMessages() {
        // 簡単な実装 - 空からスタート
        self.messages = []
    }
}