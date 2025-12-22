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
            VStack(alignment: .leading, spacing: 20) {
                headerView
                
                // チェーン詳細情報
                chainVisualizationView
                
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
                
                // アクションボタン
                if !report.skippedHabits.isEmpty {
                    actionButtonsView
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "link.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.chainName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("実行済み \(report.executedHabits.count)/\(report.expectedSequence.count) 習慣")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 完了率サークル
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: completionProgress)
                        .stroke(colorForInconsistencyLevel, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1.0), value: completionProgress)
                    
                    Text("\(Int(completionProgress * 100))%")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(colorForInconsistencyLevel)
                }
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
    
    // MARK: - 新しいビューコンポーネント
    
    private var chainVisualizationView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("習慣チェーンの状態")
                .font(.headline)
                .foregroundColor(.primary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(report.expectedSequence.enumerated()), id: \.offset) { index, habitId in
                        let isExecuted = report.executedHabits.contains(habitId)
                        let isSkipped = report.skippedHabits.contains(habitId)
                        
                        HabitChainNode(
                            habitName: habitNames[habitId] ?? "不明",
                            status: isExecuted ? .completed : (isSkipped ? .skipped : .pending),
                            isLast: index == report.expectedSequence.count - 1
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var actionButtonsView: some View {
        VStack(spacing: 12) {
            Text("クイックアクション")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                if let firstSkipped = report.skippedHabits.first {
                    Button(action: {
                        // TODO: スキップされた習慣へのクイックリマインダー
                    }) {
                        HStack {
                            Image(systemName: "bell.fill")
                            Text("「\(habitNames[firstSkipped] ?? "不明")」を今すぐ実行")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                
                Button(action: {
                    // TODO: チェーン全体のリマインダー
                }) {
                    HStack {
                        Image(systemName: "clock.fill")
                        Text("チェーン全体をリマインド")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(.orange)
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var completionProgress: Double {
        guard !report.expectedSequence.isEmpty else { return 0 }
        return Double(report.executedHabits.count) / Double(report.expectedSequence.count)
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

// MARK: - 新しいコンポーネント

struct HabitChainNode: View {
    let habitName: String
    let status: NodeStatus
    let isLast: Bool
    
    enum NodeStatus {
        case completed
        case skipped
        case pending
        
        var color: Color {
            switch self {
            case .completed: return .green
            case .skipped: return .red
            case .pending: return .gray
            }
        }
        
        var icon: String {
            switch self {
            case .completed: return "checkmark.circle.fill"
            case .skipped: return "xmark.circle.fill"
            case .pending: return "circle.dashed"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            VStack(spacing: 8) {
                Image(systemName: status.icon)
                    .font(.title2)
                    .foregroundColor(status.color)
                
                Text(habitName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(status == .completed ? .primary : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .frame(width: 80)
            }
            
            if !isLast {
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

struct OrderViolationRow: View {
    let violation: OrderViolation
    let habitNames: [UUID: String]
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.up.arrow.down.circle.fill")
                .foregroundColor(.red)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("期待順序:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("「\(habitNames[violation.expectedFirst] ?? "不明")」 → 「\(habitNames[violation.expectedSecond] ?? "不明")」")
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                
                Text("順序が逆になっています")
                    .font(.caption2)
                    .foregroundColor(.red)
                    .fontWeight(.medium)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.red.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
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