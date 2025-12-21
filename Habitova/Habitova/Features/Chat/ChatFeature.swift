//
//  ChatFeature.swift
//  Habitova
//
//  Created by Claude on 2025/12/21.
//

import Foundation
import SwiftData
// import ComposableArchitecture  // TCAパッケージ追加後にコメント解除

// MARK: - TCA版チャット機能
/*

@Reducer
struct ChatFeature {
    @ObservableState
    struct State: Equatable {
        var messages: [Message] = []
        var currentInput: String = ""
        var isLoading: Bool = false
        var conversationId = UUID()
    }
    
    enum Action {
        case sendMessage
        case messageChanged(String)
        case apiResponse(Result<ClaudeAPIService.HabitAnalysisResult, Error>)
        case loadRecentMessages
        case messagesLoaded([Message])
    }
    
    @Dependency(\.claudeAPIService) var claudeAPIService
    @Dependency(\.modelContext) var modelContext
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .sendMessage:
                let userInput = state.currentInput
                state.currentInput = ""
                state.isLoading = true
                
                // ユーザーメッセージを保存
                let userMessage = Message(
                    conversationId: state.conversationId,
                    sender: .user,
                    content: userInput
                )
                state.messages.append(userMessage)
                
                return .run { send in
                    do {
                        // 利用可能な習慣を取得
                        let availableHabits = try await fetchAvailableHabits()
                        
                        // Claude APIで分析
                        let analysisResult = try await claudeAPIService.analyzeUserInput(
                            userInput: userInput,
                            availableHabits: availableHabits,
                            conversationHistory: []
                        )
                        
                        await send(.apiResponse(.success(analysisResult)))
                    } catch {
                        await send(.apiResponse(.failure(error)))
                    }
                }
                
            case .messageChanged(let newInput):
                state.currentInput = newInput
                return .none
                
            case .apiResponse(.success(let analysisResult)):
                state.isLoading = false
                
                // AIレスポンスメッセージを作成
                let aiMessage = Message(
                    conversationId: state.conversationId,
                    sender: .assistant,
                    content: analysisResult.aiResponse
                )
                state.messages.append(aiMessage)
                
                return .none
                
            case .apiResponse(.failure(let error)):
                state.isLoading = false
                
                // エラー時のフォールバック応答
                let errorMessage = Message(
                    conversationId: state.conversationId,
                    sender: .assistant,
                    content: "申し訳ありません。処理中にエラーが発生しました。"
                )
                state.messages.append(errorMessage)
                
                return .none
                
            case .loadRecentMessages:
                return .run { send in
                    // SwiftDataから最近のメッセージを読み込み
                    let recentMessages: [Message] = [] // 実装が必要
                    await send(.messagesLoaded(recentMessages))
                }
                
            case .messagesLoaded(let messages):
                state.messages = messages
                return .none
            }
        }
    }
    
    private func fetchAvailableHabits() async throws -> [Habit] {
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                do {
                    let fetchDescriptor = FetchDescriptor<Habit>(
                        predicate: #Predicate { !$0.isArchived },
                        sortBy: [SortDescriptor(\.name)]
                    )
                    let habits = try await modelContext.fetch(fetchDescriptor)
                    continuation.resume(returning: habits)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - TCA Dependencies

extension ClaudeAPIService: DependencyKey {
    static let liveValue = ClaudeAPIService.shared
}

extension ModelContext: DependencyKey {
    static let liveValue = ModelContext(
        try! ModelContainer(for: Schema([
            Habit.self,
            Message.self,
            HabitExecution.self,
            HabitovaTask.self,
            ExecutionInference.self,
            HabitChain.self
        ])).mainContext
    )
}

extension DependencyValues {
    var claudeAPIService: ClaudeAPIService {
        get { self[ClaudeAPIService.self] }
        set { self[ClaudeAPIService.self] = newValue }
    }
    
    var modelContext: ModelContext {
        get { self[ModelContext.self] }
        set { self[ModelContext.self] = newValue }
    }
}
*/
