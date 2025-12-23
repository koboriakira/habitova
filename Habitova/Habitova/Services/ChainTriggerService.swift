//
//  ChainTriggerService.swift
//  Habitova
//
//  Created by Claude on 2025/12/22.
//

import Foundation
import SwiftData

@MainActor
class ChainTriggerService {
    static let shared = ChainTriggerService()
    
    private init() {}
    
    // MARK: - Chain-Based Trigger Generation
    
    func generateTriggerMessages(
        for executedHabitIds: [UUID],
        context: ModelContext
    ) async -> [String] {
        let triggerInfo = await generateTriggerMessagesWithSuggestions(
            for: executedHabitIds,
            context: context
        )
        return triggerInfo.messages
    }
    
    /// トリガーメッセージと提案された習慣IDを含む詳細な情報を生成
    func generateTriggerMessagesWithSuggestions(
        for executedHabitIds: [UUID],
        context: ModelContext
    ) async -> TriggerMessageInfo {
        var triggerMessages: [String] = []
        var suggestedHabitIds: [UUID] = []
        
        do {
            let habits = try await fetchHabits(context: context)
            let chains = try await fetchHabitChains(context: context)
            
            // 実行された習慣に基づいて次の習慣を特定
            for habitId in executedHabitIds {
                let nextHabitInfo = await findNextHabitMessagesWithIds(
                    triggerHabitId: habitId,
                    habits: habits,
                    chains: chains
                )
                triggerMessages.append(contentsOf: nextHabitInfo.messages)
                suggestedHabitIds.append(contentsOf: nextHabitInfo.suggestedHabitIds)
            }
            
            return TriggerMessageInfo(
                messages: triggerMessages.uniqued(),
                suggestedHabitIds: suggestedHabitIds.uniqued()
            )
            
        } catch {
            print("ChainTriggerService エラー: \(error)")
            print("ChainTriggerService エラー詳細: \(String(describing: error))")
            print("ChainTriggerService 実行された習慣ID: \(executedHabitIds)")
            return TriggerMessageInfo(messages: [], suggestedHabitIds: [])
        }
    }
    
    private func findNextHabitMessages(
        triggerHabitId: UUID,
        habits: [Habit],
        chains: [HabitChain]
    ) async -> [String] {
        let info = await findNextHabitMessagesWithIds(
            triggerHabitId: triggerHabitId,
            habits: habits,
            chains: chains
        )
        return info.messages
    }
    
    private func findNextHabitMessagesWithIds(
        triggerHabitId: UUID,
        habits: [Habit],
        chains: [HabitChain]
    ) async -> (messages: [String], suggestedHabitIds: [UUID]) {
        var messages: [String] = []
        var suggestedHabitIds: [UUID] = []
        
        // このトリガー習慣に関連するチェーンを検索
        let relevantChains = chains.filter { chain in
            chain.triggerHabits.contains(triggerHabitId)
        }
        
        for chain in relevantChains {
            if let nextHabit = habits.first(where: { $0.id == chain.nextHabitId }) {
                let message = generateTriggerMessage(
                    for: nextHabit,
                    chain: chain,
                    triggerHabit: habits.first { $0.id == triggerHabitId }
                )
                messages.append(message)
                suggestedHabitIds.append(nextHabit.id)
            }
        }
        
        return (messages, suggestedHabitIds)
    }
    
    private func generateTriggerMessage(
        for nextHabit: Habit,
        chain: HabitChain,
        triggerHabit: Habit?
    ) -> String {
        let nextHabitName = nextHabit.name
        let confidence = chain.confidence ?? 0.0
        let delayMinutes = chain.delayMinutes
        
        // 前提条件習慣のチェック
        let prerequisiteMessage = generatePrerequisiteMessage(for: chain)
        
        // 信頼度に基づいたメッセージ強度の調整
        let messagePrefix = confidence > 0.8 ? "次は" : "よろしければ次に"
        
        // 時間遅延に基づいたタイミング提案
        var timingMessage = ""
        if delayMinutes > 0 {
            if delayMinutes <= 5 {
                timingMessage = "（続けて）"
            } else if delayMinutes <= 15 {
                timingMessage = "（\(delayMinutes)分後頃に）"
            } else {
                timingMessage = "（少し時間をおいてから）"
            }
        }
        
        // 習慣名に基づいた具体的な提案メッセージ
        let actionMessage = generateActionMessage(for: nextHabit)
        
        // 前提条件がある場合はメッセージに含める
        if !prerequisiteMessage.isEmpty {
            return "\(messagePrefix)\(timingMessage)\(actionMessage)\n  ⚠️ \(prerequisiteMessage)"
        } else {
            return "\(messagePrefix)\(timingMessage)\(actionMessage)"
        }
    }
    
    /// 前提条件習慣に関するメッセージを生成
    private func generatePrerequisiteMessage(for chain: HabitChain) -> String {
        let prerequisites = chain.prerequisiteHabits
        guard !prerequisites.isEmpty else { return "" }
        
        let mandatoryPrerequisites = prerequisites.filter { $0.isMandatory }
        let optionalPrerequisites = prerequisites.filter { !$0.isMandatory }
        
        var messages: [String] = []
        
        // 必須の前提条件
        if !mandatoryPrerequisites.isEmpty {
            let names = mandatoryPrerequisites.map { prerequisite in
                if let timeMinutes = prerequisite.estimatedTimeMinutes {
                    return "\(prerequisite.habitName)（\(timeMinutes)分程度）"
                } else {
                    return prerequisite.habitName
                }
            }
            messages.append("その前に: \(names.joined(separator: "、"))")
        }
        
        // オプションの前提条件
        if !optionalPrerequisites.isEmpty {
            let names = optionalPrerequisites.map { $0.habitName }
            messages.append("可能であれば: \(names.joined(separator: "、"))")
        }
        
        return messages.joined(separator: " / ")
    }
    
    private func generateActionMessage(for habit: Habit) -> String {
        let habitName = habit.name.lowercased()
        let importance = habit.importance ?? 0.5
        
        // 重要度に基づいたトーン調整
        let urgencyPrefix = importance > 0.8 ? "" : "お時間があるときに"
        
        // 習慣名パターンマッチングによる具体的メッセージ生成
        switch habitName {
        case let name where name.contains("洗顔") || name.contains("身だしなみ"):
            return "洗顔・身だしなみを整えませんか？スッキリした気分で一日を始められます"
            
        case let name where name.contains("コーヒー"):
            return "コーヒーメーカーのスイッチを入れてはいかがでしょう？"
            
        case let name where name.contains("ストレッチ"):
            return "\(urgencyPrefix)軽いストレッチはいかがですか？体が目覚めて調子が良くなります"
            
        case let name where name.contains("朝ごはん") || name.contains("朝食"):
            if name.contains("子ども") {
                return "お子さんの朝ごはんの準備をしましょう"
            } else {
                return "朝ごはんの時間です"
            }
            
        case let name where name.contains("登園") || name.contains("送迎"):
            return "お子さんの身支度と登園準備の時間です"
            
        case let name where name.contains("自分の朝食"):
            return "お疲れ様でした！ご自分の朝食もお忘れなく"
            
        case let name where name.contains("仕事"):
            return "リモートワークの開始時間ですね。今日も頑張りましょう！"
            
        case let name where name.contains("寝かしつける"):
            return "お子さんの寝かしつけの時間です"
            
        case let name where name.contains("23時就寝"):
            return "基本の就寝時間です。今日も一日お疲れ様でした"
            
        case let name where name.contains("分割睡眠"):
            return "配信がある日ですね。一度お休みになってから楽しまれてください"
            
        case let name where name.contains("アイドル配信"):
            return "週1回の配信視聴タイムです。楽しい時間をお過ごしください"
            
        default:
            return "「\(habit.name)」\(urgencyPrefix)はいかがですか？"
        }
    }
    
    // MARK: - Time-Based Trigger Check
    
    func checkTimeBasedTriggers(
        for habitId: UUID,
        context: ModelContext
    ) async -> [String] {
        do {
            let chains = try await fetchHabitChains(context: context)
            let habits = try await fetchHabits(context: context)
            
            // この習慣をトリガーとするチェーンで時間条件を満たすものをチェック
            let eligibleChains = chains.filter { chain in
                chain.triggerHabits.contains(habitId) && 
                isTimeConditionMet(chain: chain)
            }
            
            var messages: [String] = []
            for chain in eligibleChains {
                if let nextHabit = habits.first(where: { $0.id == chain.nextHabitId }) {
                    let message = generateTimeBasedTriggerMessage(for: nextHabit, chain: chain)
                    messages.append(message)
                }
            }
            
            return messages
            
        } catch {
            print("時間ベーストリガーチェックエラー: \(error)")
            return []
        }
    }
    
    private func isTimeConditionMet(chain: HabitChain) -> Bool {
        // 現在の実装では即座にトリガー
        // 将来的には実際の時間遅延やスケジューリングを実装
        return true
    }
    
    private func generateTimeBasedTriggerMessage(for habit: Habit, chain: HabitChain) -> String {
        let delayMinutes = chain.delayMinutes
        
        if delayMinutes <= 5 {
            return "引き続き「\(habit.name)」をお忘れなく！"
        } else {
            return "そろそろ「\(habit.name)」の時間です"
        }
    }
    
    // MARK: - Data Fetching
    
    private func fetchHabits(context: ModelContext) async throws -> [Habit] {
        let fetchDescriptor = FetchDescriptor<Habit>(
            predicate: #Predicate<Habit> { habit in
                !habit.isArchived
            }
        )
        return try context.fetch(fetchDescriptor)
    }
    
    private func fetchHabitChains(context: ModelContext) async throws -> [HabitChain] {
        let fetchDescriptor = FetchDescriptor<HabitChain>()
        return try context.fetch(fetchDescriptor)
    }
}

// MARK: - Supporting Types

/// トリガーメッセージ情報
struct TriggerMessageInfo: Sendable {
    let messages: [String]
    let suggestedHabitIds: [UUID]
}

// MARK: - Array Extension

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}