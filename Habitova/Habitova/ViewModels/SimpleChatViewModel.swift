//
//  SimpleChatViewModel.swift
//  Habitova
//
//  Created by Claude on 2025/12/21.
//

import Foundation
import SwiftData
import Combine
import SwiftUI

@MainActor
class SimpleChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var currentInput: String = ""
    @Published var isLoading: Bool = false
    @Published var lastChainReport: ChainConsistencyReport?
    @Published var errorMessage: String?
    @Published var showingError: Bool = false
    @Published var connectionStatus: ConnectionStatus = .unknown
    
    enum ConnectionStatus: Equatable {
        case connected
        case disconnected
        case unknown
        case error(String)
        
        var displayText: String {
            switch self {
            case .connected: return "接続中"
            case .disconnected: return "オフライン"
            case .unknown: return "確認中"
            case .error(let message): return "エラー: \(message)"
            }
        }
        
        var color: Color {
            switch self {
            case .connected: return .green
            case .disconnected: return .orange
            case .unknown: return .gray
            case .error: return .red
            }
        }
    }
    
    private let modelContext: ModelContext
    private let claudeAPIService: ClaudeAPIService
    private let chainChecker: ChainConsistencyChecker
    private let conversationId = UUID()
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.claudeAPIService = ClaudeAPIService.shared
        self.chainChecker = ChainConsistencyChecker(modelContext: modelContext)
        loadRecentMessages()
        checkConnectionStatus()
    }
    
    func checkConnectionStatus() {
        Task {
            if claudeAPIService.isAPIKeyConfigured() {
                connectionStatus = .connected
            } else {
                connectionStatus = .disconnected
            }
        }
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
            
            // 詳細なエラーハンドリング
            let errorContent = handleError(error, userInput: userMessageContent)
            let errorMessage = Message(
                conversationId: conversationId,
                sender: .assistant,
                content: errorContent
            )
            
            modelContext.insert(errorMessage)
            messages.append(errorMessage)
            
            // エラー状態の更新
            updateConnectionStatusOnError(error)
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
        // 会話履歴の読み込み（最近の20件まで）
        let fetchDescriptor = FetchDescriptor<Message>(
            predicate: #Predicate<Message> { $0.conversationId == conversationId },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        
        do {
            let allMessages = try modelContext.fetch(fetchDescriptor)
            self.messages = Array(allMessages.suffix(20)) // 最近の20件
        } catch {
            print("Error loading messages: \(error)")
            self.messages = []
        }
    }
    
    private func handleError(_ error: Error, userInput: String) -> String {
        return "エラーが発生しました。\n\nあなたのメッセージ: \"\(userInput)\"\n\nお試しください:\n• インターネット接続を確認\n• アプリを再起動\n• 設定でAPIキーを確認\n• しばらく待ってから再試行"
    }
    
    private func updateConnectionStatusOnError(_ error: Error) {
        connectionStatus = .error("通信エラー")
    }
    
    func retryLastMessage() {
        guard let lastUserMessage = messages.reversed().first(where: { $0.sender == .user }) else {
            return
        }
        
        currentInput = lastUserMessage.content
        Task {
            await sendMessage()
        }
    }
    
    func clearConversation() {
        // 現在の会話をクリア
        for message in messages {
            modelContext.delete(message)
        }
        
        messages.removeAll()
        lastChainReport = nil
        
        do {
            try modelContext.save()
        } catch {
            print("Error clearing conversation: \(error)")
        }
    }
}