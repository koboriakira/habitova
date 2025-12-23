//
//  SuggestionResponseService.swift
//  Habitova
//
//  Created by Claude on 2025/12/23.
//

import Foundation
import SwiftData

@MainActor
class SuggestionResponseService {
    static let shared = SuggestionResponseService()
    
    private init() {}
    
    /// ユーザーの応答がAI提案に対する実行確認かを判定し、実行された習慣を抽出
    func analyzeSuggestionResponse(
        userInput: String,
        conversationHistory: [Message],
        context: ModelContext
    ) async -> SuggestionResponseResult? {
        
        print("SuggestionResponseService: ユーザー入力分析開始: '\(userInput)'")
        
        // 最近のAI提案メッセージを取得（過去3件以内）
        let recentAIMessages = conversationHistory.suffix(6).filter { $0.sender == .assistant }
        
        guard let latestAISuggestion = recentAIMessages.last,
              let suggestedHabitIds = latestAISuggestion.suggestedHabitIds,
              !suggestedHabitIds.isEmpty else {
            print("SuggestionResponseService: 最近のAI提案が見つかりません")
            return nil
        }
        
        print("SuggestionResponseService: 最近のAI提案: '\(latestAISuggestion.content)'")
        print("SuggestionResponseService: 提案された習慣ID: \(suggestedHabitIds)")
        
        // 実行確認のパターンマッチング
        if isExecutionConfirmation(userInput) {
            print("SuggestionResponseService: 実行確認として認識")
            
            // 提案された習慣を取得
            let suggestedHabits = try? await getSuggestedHabits(ids: suggestedHabitIds, context: context)
            
            if let habits = suggestedHabits, !habits.isEmpty {
                print("SuggestionResponseService: 実行確認された習慣: \(habits.map { $0.name })")
                
                let inferredHabits = habits.map { habit in
                    InferredHabit(
                        habitId: habit.id,
                        habitName: habit.name,
                        executionType: .direct,
                        completionPercentage: 100,
                        confidence: 0.9
                    )
                }
                
                return SuggestionResponseResult(
                    isSuggestionResponse: true,
                    executedHabits: inferredHabits,
                    originalSuggestionMessage: latestAISuggestion
                )
            }
        } else {
            print("SuggestionResponseService: 実行確認として認識されず")
        }
        
        return nil
    }
    
    /// ユーザー入力が実行確認パターンかを判定
    private func isExecutionConfirmation(_ input: String) -> Bool {
        let lowercased = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 実行確認のパターン
        let confirmationPatterns = [
            // 基本パターン
            "やりました", "しました", "できました", "やった", "した", "できた",
            "実行しました", "実行した", "完了しました", "完了した",
            "済ませました", "済ませた", "終わりました", "終わった",
            
            // 丁寧語
            "やらせていただきました", "させていただきました",
            "実行させていただきました", "完了させていただきました",
            
            // カジュアル
            "やったよ", "したよ", "できたよ", "やったー", "やったです",
            "ok", "オーケー", "おけ", "はい",
            
            // 部分実行
            "ちょっとやりました", "少しやりました", "一部やりました",
            "途中までやりました", "やってみました",
            
            // 時制表現
            "さっきやりました", "先ほどやりました", "今やりました",
            "ついさっきやった", "さっきした", "今した"
        ]
        
        // 完全一致または部分一致をチェック
        for pattern in confirmationPatterns {
            if lowercased == pattern || lowercased.contains(pattern) {
                return true
            }
        }
        
        // 否定表現をチェック（これらが含まれている場合は実行確認ではない）
        let negativePatterns = [
            "やりません", "しません", "できません", "やらない", "しない", "できない",
            "まだ", "これから", "あとで", "後で", "忘れた", "忘れました"
        ]
        
        for pattern in negativePatterns {
            if lowercased.contains(pattern) {
                return false
            }
        }
        
        // 疑問文チェック（実行確認ではない）
        if lowercased.contains("？") || lowercased.contains("?") || 
           lowercased.hasPrefix("いつ") || lowercased.hasPrefix("どう") || 
           lowercased.hasPrefix("何") {
            return false
        }
        
        return false
    }
    
    /// 提案された習慣IDから習慣を取得
    private func getSuggestedHabits(ids: [UUID], context: ModelContext) async throws -> [Habit] {
        var habits: [Habit] = []
        
        for id in ids {
            let fetchDescriptor = FetchDescriptor<Habit>(
                predicate: #Predicate<Habit> { $0.id == id }
            )
            
            if let habit = try context.fetch(fetchDescriptor).first {
                habits.append(habit)
            }
        }
        
        return habits
    }
}

/// 提案応答解析結果
struct SuggestionResponseResult: Sendable {
    let isSuggestionResponse: Bool
    let executedHabits: [InferredHabit]
    let originalSuggestionMessage: Message?
}