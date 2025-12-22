//
//  DataExportService.swift
//  Habitova
//
//  Created by Claude on 2025/12/22.
//

import Foundation
import SwiftData
import UniformTypeIdentifiers
import Combine

@MainActor
class DataExportService: ObservableObject {
    static let shared = DataExportService()
    
    @Published var isExporting = false
    @Published var exportProgress: Double = 0.0
    @Published var lastExportDate: Date?
    
    private init() {}
    
    // MARK: - Export Options
    
    enum ExportFormat: String, CaseIterable {
        case json = "json"
        case csv = "csv"
        case txt = "txt"
        
        var displayName: String {
            switch self {
            case .json:
                return "JSON形式"
            case .csv:
                return "CSV形式"
            case .txt:
                return "テキスト形式"
            }
        }
        
        var fileExtension: String {
            return rawValue
        }
        
        var utType: UTType {
            switch self {
            case .json:
                return .json
            case .csv:
                return .commaSeparatedText
            case .txt:
                return .plainText
            }
        }
    }
    
    enum ExportScope: String, CaseIterable {
        case all = "all"
        case habits = "habits"
        case executions = "executions"
        case chains = "chains"
        case messages = "messages"
        
        var displayName: String {
            switch self {
            case .all:
                return "すべてのデータ"
            case .habits:
                return "習慣データ"
            case .executions:
                return "実行記録"
            case .chains:
                return "チェーンデータ"
            case .messages:
                return "メッセージ履歴"
            }
        }
    }
    
    // MARK: - Main Export Function
    
    func exportData(
        format: ExportFormat,
        scope: ExportScope,
        context: ModelContext,
        dateRange: DateInterval? = nil
    ) async throws -> Data {
        isExporting = true
        exportProgress = 0.0
        
        defer {
            isExporting = false
            exportProgress = 1.0
            lastExportDate = Date()
        }
        
        do {
            let exportData = try await collectData(scope: scope, context: context, dateRange: dateRange)
            exportProgress = 0.5
            
            let formattedData = try formatData(exportData, format: format)
            exportProgress = 1.0
            
            return formattedData
        } catch {
            isExporting = false
            throw error
        }
    }
    
    // MARK: - Data Collection
    
    private func collectData(
        scope: ExportScope,
        context: ModelContext,
        dateRange: DateInterval? = nil
    ) async throws -> ExportData {
        var exportData = ExportData()
        
        switch scope {
        case .all:
            exportData.habits = try fetchHabits(context: context)
            exportData.executions = try fetchExecutions(context: context, dateRange: dateRange)
            exportData.chains = try fetchChains(context: context)
            exportData.messages = try fetchMessages(context: context, dateRange: dateRange)
            
        case .habits:
            exportData.habits = try fetchHabits(context: context)
            
        case .executions:
            exportData.executions = try fetchExecutions(context: context, dateRange: dateRange)
            
        case .chains:
            exportData.chains = try fetchChains(context: context)
            
        case .messages:
            exportData.messages = try fetchMessages(context: context, dateRange: dateRange)
        }
        
        exportData.metadata = ExportMetadata(
            exportDate: Date(),
            scope: scope.rawValue,
            dateRange: dateRange,
            appVersion: "1.0.0",
            dataVersion: "1.0"
        )
        
        return exportData
    }
    
    private func fetchHabits(context: ModelContext) throws -> [ExportableHabit] {
        let fetchDescriptor = FetchDescriptor<Habit>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let habits = try context.fetch(fetchDescriptor)
        
        return habits.map { habit in
            ExportableHabit(
                id: habit.id.uuidString,
                name: habit.name,
                description: habit.habitDescription,
                targetFrequency: habit.targetFrequency,
                importance: habit.importance,
                importanceInferred: habit.importanceInferred,
                level: habit.level,
                isArchived: habit.isArchived,
                createdAt: habit.createdAt,
                updatedAt: habit.updatedAt,
                hiddenParameters: habit.hiddenParameters
            )
        }
    }
    
    private func fetchExecutions(context: ModelContext, dateRange: DateInterval?) throws -> [ExportableExecution] {
        var fetchDescriptor = FetchDescriptor<HabitExecution>(
            sortBy: [SortDescriptor(\.executedAt, order: .forward)]
        )
        
        if let dateRange = dateRange {
            fetchDescriptor.predicate = #Predicate<HabitExecution> { execution in
                execution.executedAt >= dateRange.start && execution.executedAt <= dateRange.end
            }
        }
        
        let executions = try context.fetch(fetchDescriptor)
        
        return executions.map { execution in
            ExportableExecution(
                id: execution.id.uuidString,
                habitId: execution.habit?.id.uuidString,
                habitName: execution.habit?.name,
                executedAt: execution.executedAt,
                completionPercentage: execution.completionPercentage,
                executionType: execution.executionType.rawValue,
                daysChain: execution.daysChain,
                messageContent: execution.message?.content
            )
        }
    }
    
    private func fetchChains(context: ModelContext) throws -> [ExportableChain] {
        let fetchDescriptor = FetchDescriptor<HabitChain>()
        let chains = try context.fetch(fetchDescriptor)
        
        return chains.map { chain in
            ExportableChain(
                id: chain.id.uuidString,
                triggerHabits: chain.triggerHabits.map { $0.uuidString },
                nextHabitId: chain.nextHabitId.uuidString,
                delayMinutes: chain.delayMinutes,
                confidence: chain.confidence,
                triggerCondition: chain.triggerCondition ?? TriggerCondition(type: "unknown", delayMinutes: 0, context: nil)
            )
        }
    }
    
    private func fetchMessages(context: ModelContext, dateRange: DateInterval?) throws -> [ExportableMessage] {
        var fetchDescriptor = FetchDescriptor<Message>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        
        if let dateRange = dateRange {
            fetchDescriptor.predicate = #Predicate<Message> { message in
                message.createdAt >= dateRange.start && message.createdAt <= dateRange.end
            }
        }
        
        let messages = try context.fetch(fetchDescriptor)
        
        return messages.map { message in
            ExportableMessage(
                id: message.id.uuidString,
                content: message.content,
                sender: message.sender.rawValue,
                createdAt: message.createdAt
            )
        }
    }
    
    // MARK: - Data Formatting
    
    private func formatData(_ exportData: ExportData, format: ExportFormat) throws -> Data {
        switch format {
        case .json:
            return try formatAsJSON(exportData)
        case .csv:
            return try formatAsCSV(exportData)
        case .txt:
            return try formatAsText(exportData)
        }
    }
    
    private func formatAsJSON(_ exportData: ExportData) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(exportData)
    }
    
    private func formatAsCSV(_ exportData: ExportData) throws -> Data {
        var csvContent = ""
        
        // メタデータ
        csvContent += "# Habitova データエクスポート\n"
        csvContent += "# エクスポート日時: \(ISO8601DateFormatter().string(from: exportData.metadata?.exportDate ?? Date()))\n"
        csvContent += "# スコープ: \(exportData.metadata?.scope ?? "unknown")\n\n"
        
        // 習慣データ
        if let habits = exportData.habits, !habits.isEmpty {
            csvContent += "## 習慣データ\n"
            csvContent += "ID,名前,説明,頻度,重要度,レベル,アーカイブ,作成日,更新日\n"
            for habit in habits {
                csvContent += "\"\(habit.id)\",\"\(habit.name)\",\"\(habit.description)\",\"\(habit.targetFrequency)\",\"\(habit.importance ?? 0.0)\",\"\(habit.level)\",\"\(habit.isArchived)\",\"\(ISO8601DateFormatter().string(from: habit.createdAt))\",\"\(ISO8601DateFormatter().string(from: habit.updatedAt))\"\n"
            }
            csvContent += "\n"
        }
        
        // 実行記録
        if let executions = exportData.executions, !executions.isEmpty {
            csvContent += "## 実行記録\n"
            csvContent += "ID,習慣ID,習慣名,実行日時,完了率,実行タイプ,連続日数,メッセージ\n"
            for execution in executions {
                csvContent += "\"\(execution.id)\",\"\(execution.habitId ?? "")\",\"\(execution.habitName ?? "")\",\"\(ISO8601DateFormatter().string(from: execution.executedAt))\",\"\(execution.completionPercentage)\",\"\(execution.executionType)\",\"\(execution.daysChain)\",\"\(execution.messageContent ?? "")\"\n"
            }
            csvContent += "\n"
        }
        
        return csvContent.data(using: .utf8) ?? Data()
    }
    
    private func formatAsText(_ exportData: ExportData) throws -> Data {
        var textContent = ""
        
        // ヘッダー
        textContent += "=== Habitova データエクスポート ===\n"
        textContent += "エクスポート日時: \(DateFormatter.fullDateTime.string(from: exportData.metadata?.exportDate ?? Date()))\n"
        textContent += "スコープ: \(exportData.metadata?.scope ?? "unknown")\n\n"
        
        // 習慣データ
        if let habits = exportData.habits, !habits.isEmpty {
            textContent += "【習慣データ】(\(habits.count)件)\n"
            textContent += String(repeating: "-", count: 50) + "\n"
            for habit in habits {
                textContent += "名前: \(habit.name)\n"
                textContent += "説明: \(habit.description)\n"
                textContent += "頻度: \(habit.targetFrequency)\n"
                textContent += "重要度: \(String(format: "%.2f", habit.importance ?? 0.0))\n"
                textContent += "作成日: \(DateFormatter.shortDate.string(from: habit.createdAt))\n\n"
            }
        }
        
        // 実行記録
        if let executions = exportData.executions, !executions.isEmpty {
            textContent += "【実行記録】(\(executions.count)件)\n"
            textContent += String(repeating: "-", count: 50) + "\n"
            for execution in executions {
                textContent += "習慣: \(execution.habitName ?? "不明")\n"
                textContent += "実行日時: \(DateFormatter.fullDateTime.string(from: execution.executedAt))\n"
                textContent += "完了率: \(execution.completionPercentage)%\n"
                textContent += "実行タイプ: \(execution.executionType)\n"
                if let message = execution.messageContent {
                    textContent += "メッセージ: \(message)\n"
                }
                textContent += "\n"
            }
        }
        
        return textContent.data(using: .utf8) ?? Data()
    }
    
    // MARK: - File Naming
    
    func generateFileName(format: ExportFormat, scope: ExportScope) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        
        let scopePrefix = scope == .all ? "habitova-data" : "habitova-\(scope.rawValue)"
        return "\(scopePrefix)_\(timestamp).\(format.fileExtension)"
    }
}

// MARK: - Data Models

struct ExportData: Codable {
    var metadata: ExportMetadata?
    var habits: [ExportableHabit]?
    var executions: [ExportableExecution]?
    var chains: [ExportableChain]?
    var messages: [ExportableMessage]?
}

struct ExportMetadata: Codable {
    let exportDate: Date
    let scope: String
    let dateRange: DateInterval?
    let appVersion: String
    let dataVersion: String
}

struct ExportableHabit: Codable {
    let id: String
    let name: String
    let description: String
    let targetFrequency: String
    let importance: Double?
    let importanceInferred: Double?
    let level: Int
    let isArchived: Bool
    let createdAt: Date
    let updatedAt: Date
    let hiddenParameters: Habit.HiddenParameters?
}

struct ExportableExecution: Codable {
    let id: String
    let habitId: String?
    let habitName: String?
    let executedAt: Date
    let completionPercentage: Int
    let executionType: String
    let daysChain: Int
    let messageContent: String?
}

struct ExportableChain: Codable {
    let id: String
    let triggerHabits: [String]
    let nextHabitId: String
    let delayMinutes: Int
    let confidence: Double?
    let triggerCondition: TriggerCondition
}

struct ExportableMessage: Codable {
    let id: String
    let content: String
    let sender: String
    let createdAt: Date
}

// MARK: - DateFormatter Extensions

extension DateFormatter {
    static let fullDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
    
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
}