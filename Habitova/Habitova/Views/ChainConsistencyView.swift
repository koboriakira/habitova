//
//  ChainConsistencyView.swift
//  Habitova
//
//  Created by Claude on 2025/12/21.
//

import SwiftUI
import SwiftData

struct ChainConsistencyView: View {
    let report: ChainConsistencyReport
    @Environment(\.modelContext) private var modelContext
    @State private var habitNames: [UUID: String] = [:]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerView
                
                if report.inconsistencyLevel > 0 {
                    inconsistencyIndicator
                    
                    if !report.skippedHabits.isEmpty {
                        skippedHabitsSection
                    }
                    
                    if !report.unexpectedHabits.isEmpty {
                        unexpectedHabitsSection
                    }
                    
                    if !report.executionOrder.violations.isEmpty {
                        orderViolationsSection
                    }
                } else {
                    perfectChainView
                }
                
                if !report.suggestions.isEmpty {
                    suggestionsSection
                }
            }
            .padding()
        }
        .navigationTitle("チェーン整合性")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadHabitNames()
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(report.chainName)
                .font(.title2)
                .fontWeight(.bold)
            
            HStack {
                Image(systemName: "link.circle.fill")
                    .foregroundColor(.blue)
                
                Text("実行済み: \(report.executedHabits.count)/\(report.expectedSequence.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var inconsistencyIndicator: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(colorForInconsistencyLevel)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("不整合レベル")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(String(format: "%.1f%%", report.inconsistencyLevel * 100))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(colorForInconsistencyLevel)
            }
            
            Spacer()
            
            ProgressView(value: report.inconsistencyLevel)
                .progressViewStyle(LinearProgressViewStyle(tint: colorForInconsistencyLevel))
                .frame(width: 100)
        }
        .padding()
        .background(colorForInconsistencyLevel.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var skippedHabitsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("スキップされた習慣")
                .font(.headline)
                .foregroundColor(.orange)
            
            ForEach(report.skippedHabits, id: \.self) { habitId in
                HabitRowView(habitId: habitId, habitName: habitNames[habitId] ?? "不明な習慣", status: .skipped)
            }
        }
    }
    
    private var unexpectedHabits: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("予定外の習慣")
                .font(.headline)
                .foregroundColor(.purple)
            
            ForEach(report.unexpectedHabits, id: \.self) { habitId in
                HabitRowView(habitId: habitId, habitName: habitNames[habitId] ?? "不明な習慣", status: .unexpected)
            }
        }
    }
    
    private var unexpectedHabitsSection: some View {
        unexpectedHabits
    }
    
    private var orderViolationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("順序の問題")
                .font(.headline)
                .foregroundColor(.red)
            
            ForEach(Array(report.executionOrder.violations.enumerated()), id: \.offset) { _, violation in
                OrderViolationRow(violation: violation, habitNames: habitNames)
            }
        }
    }
    
    private var perfectChainView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
            
            Text("完璧なチェーン実行！")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.green)
            
            Text("すべての習慣が正しい順序で実行されました")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("提案")
                .font(.headline)
                .foregroundColor(.blue)
            
            ForEach(report.suggestions, id: \.self) { suggestion in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    
                    Text(suggestion)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var colorForInconsistencyLevel: Color {
        switch report.inconsistencyLevel {
        case 0.0..<0.3:
            return .green
        case 0.3..<0.7:
            return .orange
        default:
            return .red
        }
    }
    
    private func loadHabitNames() {
        let allHabitIds = Set(report.expectedSequence + report.executedHabits + report.skippedHabits + report.unexpectedHabits)
        
        let fetchDescriptor = FetchDescriptor<Habit>(
            predicate: #Predicate<Habit> { habit in
                allHabitIds.contains(habit.id)
            }
        )
        
        do {
            let habits = try modelContext.fetch(fetchDescriptor)
            habitNames = Dictionary(uniqueKeysWithValues: habits.map { ($0.id, $0.name) })
        } catch {
            print("Error loading habit names: \(error)")
        }
    }
}

struct HabitRowView: View {
    let habitId: UUID
    let habitName: String
    let status: HabitStatus
    
    enum HabitStatus {
        case completed
        case skipped
        case unexpected
    }
    
    var body: some View {
        HStack {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .font(.caption)
            
            Text(habitName)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(statusText)
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(statusColor.opacity(0.2))
                .foregroundColor(statusColor)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
    
    private var statusIcon: String {
        switch status {
        case .completed:
            return "checkmark.circle.fill"
        case .skipped:
            return "minus.circle.fill"
        case .unexpected:
            return "plus.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .completed:
            return .green
        case .skipped:
            return .orange
        case .unexpected:
            return .purple
        }
    }
    
    private var statusText: String {
        switch status {
        case .completed:
            return "完了"
        case .skipped:
            return "スキップ"
        case .unexpected:
            return "予定外"
        }
    }
}

struct OrderViolationRow: View {
    let violation: OrderViolation
    let habitNames: [UUID: String]
    
    var body: some View {
        HStack {
            Image(systemName: "arrow.up.arrow.down.circle.fill")
                .foregroundColor(.red)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("「\(habitNames[violation.expectedFirst] ?? "不明")」→「\(habitNames[violation.expectedSecond] ?? "不明")」")
                    .font(.caption)
                    .foregroundColor(.primary)
                
                Text("順序が逆になっています")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let sampleReport = ChainConsistencyReport(
        chainId: UUID(),
        chainName: "朝のルーティン",
        expectedSequence: [UUID(), UUID(), UUID()],
        executedHabits: [UUID(), UUID()],
        skippedHabits: [UUID()],
        unexpectedHabits: [],
        executionOrder: ExecutionOrderAnalysis(correctOrder: true, violations: [], executionTimes: [:]),
        inconsistencyLevel: 0.33,
        suggestions: ["「洗顔」もお忘れなく！", "朝のルーティンを完成させましょう"]
    )
    
    NavigationView {
        ChainConsistencyView(report: sampleReport)
    }
    .modelContainer(for: [Habit.self, Message.self, HabitExecution.self, HabitovaTask.self, ExecutionInference.self, HabitChain.self], inMemory: true)
}