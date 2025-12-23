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
        
        // 初期化後に非同期で読み込み
        Task {
            await loadRecentMessagesAsync()
            await checkConnectionStatusAsync()
        }
    }
    
    func checkConnectionStatus() {
        Task {
            await checkConnectionStatusAsync()
        }
    }
    
    @MainActor
    private func checkConnectionStatusAsync() async {
        if claudeAPIService.isAPIKeyConfigured() {
            connectionStatus = .connected
        } else {
            connectionStatus = .disconnected
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
        
        // 確実にローディング状態をクリアする
        defer {
            isLoading = false
            print("SimpleChatViewModel: isLoading set to false in defer")
        }
        
        // タイムアウト設定（10秒）
        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10秒
            if !Task.isCancelled {
                print("SimpleChatViewModel: Timeout reached after 10 seconds, forcing isLoading to false")
                await MainActor.run {
                    isLoading = false
                    let timeoutMessage = Message(
                        conversationId: conversationId,
                        sender: .assistant,
                        content: "⏰ タイムアウト: 処理に時間がかかりすぎています。\n\nデバッグ情報: 10秒でタイムアウトしました。ログを確認してください。"
                    )
                    modelContext.insert(timeoutMessage)
                    messages.append(timeoutMessage)
                    try? modelContext.save()
                }
            }
        }
        
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
        print("SimpleChatViewModel: 利用可能な習慣数: \(availableHabits.count)")
        
        do {
            // まず、AI提案への応答かどうかをチェック
            print("SimpleChatViewModel: 提案応答チェック開始")
            let suggestionResponseService = SuggestionResponseService.shared
            let suggestionResponse = await suggestionResponseService.analyzeSuggestionResponse(
                userInput: userMessageContent,
                conversationHistory: messages,
                context: modelContext
            )
            
            var finalExtractedHabits: [InferredHabit] = []
            
            if let suggestionResult = suggestionResponse {
                print("SimpleChatViewModel: 提案応答として認識、習慣数: \(suggestionResult.executedHabits.count)")
                finalExtractedHabits = suggestionResult.executedHabits
            } else {
                // 通常のClaude API分析を実行
                print("SimpleChatViewModel: Claude API呼び出し開始")
                let analysisResult = try await claudeAPIService.analyzeUserInput(
                    userInput: userMessageContent,
                    availableHabits: availableHabits,
                    conversationHistory: messages.suffix(5).map { $0 }
                )
                print("SimpleChatViewModel: Claude API呼び出し成功、抽出された習慣数: \(analysisResult.extractedHabits.count)")
                finalExtractedHabits = analysisResult.extractedHabits
            }
            
            // 抽出された習慣の実行記録を保存
            await saveHabitExecutions(finalExtractedHabits)
            
            // チェーン整合性をチェック
            let executedHabitIds = finalExtractedHabits.map { $0.habitId }
            print("SimpleChatViewModel: チェーン整合性チェック開始、習慣ID: \(executedHabitIds)")
            lastChainReport = await chainChecker.checkChainConsistency(for: executedHabitIds)
            print("SimpleChatViewModel: チェーン整合性チェック完了")
            
            // チェーンベーストリガーメッセージを生成（提案習慣IDも取得）
            print("SimpleChatViewModel: トリガーメッセージ生成開始")
            let triggerInfo = await ChainTriggerService.shared.generateTriggerMessagesWithSuggestions(
                for: executedHabitIds,
                context: modelContext
            )
            print("SimpleChatViewModel: トリガーメッセージ生成完了、メッセージ数: \(triggerInfo.messages.count), 提案習慣数: \(triggerInfo.suggestedHabitIds.count)")
            
            // AI応答の生成
            var enhancedResponse: String
            
            if let suggestionResult = suggestionResponse {
                // 提案応答の場合、確認メッセージを生成
                let habitNames = suggestionResult.executedHabits.map { $0.habitName }.joined(separator: "、")
                enhancedResponse = "✅ \(habitNames)を実行されたんですね。素晴らしいです！"
            } else {
                // 通常のAPI分析結果を使用
                enhancedResponse = (try? await claudeAPIService.analyzeUserInput(
                    userInput: userMessageContent,
                    availableHabits: availableHabits,
                    conversationHistory: messages.suffix(5).map { $0 }
                ).aiResponse) ?? "ありがとうございます。"
            }
            
            // チェーン整合性の結果を追加
            if let report = lastChainReport, !report.suggestions.isEmpty {
                enhancedResponse += "\n\n💡 " + report.suggestions.joined(separator: "\n💡 ")
            }
            
            // チェーントリガーメッセージを追加
            if !triggerInfo.messages.isEmpty {
                enhancedResponse += "\n\n🔗 " + triggerInfo.messages.joined(separator: "\n🔗 ")
            }
            
            // AI応答を作成（提案された習慣IDも保存）
            let aiMessage = Message(
                conversationId: conversationId,
                sender: .assistant,
                content: enhancedResponse,
                suggestedHabitsData: !triggerInfo.suggestedHabitIds.isEmpty ? 
                    try? JSONEncoder().encode(triggerInfo.suggestedHabitIds) : nil
            )
            
            modelContext.insert(aiMessage)
            messages.append(aiMessage)
            
        } catch {
            print("SimpleChatViewModel: Claude API Error: \(error)")
            print("SimpleChatViewModel: Error details: \(String(describing: error))")
            print("SimpleChatViewModel: Error type: \(type(of: error))")
            
            // より詳細なエラーログ
            if let apiError = error as? APIError {
                print("SimpleChatViewModel: APIError type: \(apiError)")
                switch apiError {
                case .invalidResponse:
                    print("SimpleChatViewModel: Invalid API response received")
                case .invalidJSON:
                    print("SimpleChatViewModel: JSON parsing failed")
                case .parsingError(let innerError):
                    print("SimpleChatViewModel: Parsing error: \(innerError)")
                case .networkError(let networkError):
                    print("SimpleChatViewModel: Network error: \(networkError)")
                }
            }
            
            // Task cancellation check
            if error is CancellationError {
                print("SimpleChatViewModel: Task was cancelled")
                return // タスクがキャンセルされた場合は処理を中止
            }
            
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
        
        // タイムアウトタスクをキャンセル
        timeoutTask.cancel()
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving: \(error)")
        }
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
        print("SimpleChatViewModel: saveHabitExecutions called with \(inferredHabits.count) habits")
        for inferredHabit in inferredHabits {
            print("SimpleChatViewModel: Processing habit \(inferredHabit.habitName) (ID: \(inferredHabit.habitId))")
            // 該当する習慣を検索
            let fetchDescriptor = FetchDescriptor<Habit>(
                predicate: #Predicate<Habit> { $0.id == inferredHabit.habitId }
            )
            
            guard let habit = try? modelContext.fetch(fetchDescriptor).first else {
                print("SimpleChatViewModel: Habit not found for ID: \(inferredHabit.habitId)")
                continue
            }
            
            print("SimpleChatViewModel: Found habit: \(habit.name)")
            
            // 習慣実行記録を作成
            let execution = HabitExecution(
                habit: habit,
                message: messages.last,
                executionType: inferredHabit.executionType,
                completionPercentage: inferredHabit.completionPercentage,
                executedAt: Date()
            )
            
            modelContext.insert(execution)
            print("SimpleChatViewModel: Created execution record for \(habit.name)")
        }
    }
    
    private func loadRecentMessages() {
        // 後方互換性のため残す
        Task {
            await loadRecentMessagesAsync()
        }
    }
    
    @MainActor
    private func loadRecentMessagesAsync() async {
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