//
//  HabitExecutionListView.swift
//  Habitova
//
//  Created by Claude on 2025/12/21.
//

import SwiftUI
import SwiftData

struct HabitExecutionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HabitExecution.executedAt, order: .reverse) private var executions: [HabitExecution]
    @Query private var habits: [Habit]
    @State private var selectedDateRange: DateRangeFilter = .today
    @State private var showingStatsSheet = false
    
    enum DateRangeFilter: String, CaseIterable {
        case today = "今日"
        case thisWeek = "今週"
        case thisMonth = "今月"
        case all = "全期間"
        
        var dateRange: (Date, Date) {
            let calendar = Calendar.current
            let now = Date()
            
            switch self {
            case .today:
                let start = calendar.startOfDay(for: now)
                let end = calendar.date(byAdding: .day, value: 1, to: start)!
                return (start, end)
            case .thisWeek:
                let start = calendar.dateInterval(of: .weekOfYear, for: now)!.start
                let end = calendar.dateInterval(of: .weekOfYear, for: now)!.end
                return (start, end)
            case .thisMonth:
                let start = calendar.dateInterval(of: .month, for: now)!.start
                let end = calendar.dateInterval(of: .month, for: now)!.end
                return (start, end)
            case .all:
                return (Date.distantPast, Date.distantFuture)
            }
        }
    }
    
    private var filteredExecutions: [HabitExecution] {
        let (startDate, endDate) = selectedDateRange.dateRange
        return executions.filter { execution in
            execution.executedAt >= startDate && execution.executedAt < endDate
        }
    }
    
    private var executionStats: ExecutionStats {
        calculateStats(from: filteredExecutions)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // フィルターとサマリー
                headerSectionView
                
                // 実行記録リスト
                List {
                    if filteredExecutions.isEmpty {
                        ContentUnavailableView {
                            Label("実行記録なし", systemImage: "checkmark.circle")
                        } description: {
                            Text(selectedDateRange == .today ? "今日はまだ習慣の実行記録がありません" : "選択した期間の実行記録がありません")
                        }
                    } else {
                        ForEach(groupedExecutions, id: \.key) { groupItem in
                            Section(header: DaySectionHeader(dateString: groupItem.key, executions: groupItem.value)) {
                                ForEach(groupItem.value) { execution in
                                    EnhancedHabitExecutionRow(execution: execution)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("実行記録")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingStatsSheet = true }) {
                        Image(systemName: "chart.bar.fill")
                    }
                }
            }
            .sheet(isPresented: $showingStatsSheet) {
                ExecutionStatsView(stats: executionStats, habits: habits)
            }
        }
    }
    
    private var headerSectionView: some View {
        VStack(spacing: 12) {
            // 日付フィルター
            Picker("期間", selection: $selectedDateRange) {
                ForEach(DateRangeFilter.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            // クイック統計
            quickStatsView
        }
        .padding(.vertical, 8)
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    private var quickStatsView: some View {
        HStack(spacing: 20) {
            StatCard(title: "実行数", value: "\(filteredExecutions.count)", color: .blue)
            StatCard(title: "平均完了率", value: "\(Int(executionStats.averageCompletion))%", color: .green)
            StatCard(title: "習慣種類", value: "\(executionStats.uniqueHabitsCount)", color: .orange)
        }
        .padding(.horizontal)
    }
    
    private var groupedExecutions: [(key: String, value: [HabitExecution])] {
        let grouped = Dictionary(grouping: filteredExecutions) { execution in
            DateFormatter.dayFormatter.string(from: execution.executedAt)
        }
        return grouped.sorted { $0.key > $1.key }
    }
    
    private func calculateStats(from executions: [HabitExecution]) -> ExecutionStats {
        guard !executions.isEmpty else {
            return ExecutionStats(totalExecutions: 0, averageCompletion: 0, uniqueHabitsCount: 0)
        }
        
        let totalCompletion = executions.reduce(0) { $0 + $1.completionPercentage }
        let averageCompletion = Double(totalCompletion) / Double(executions.count)
        let uniqueHabits = Set(executions.compactMap { $0.habit?.id })
        
        return ExecutionStats(
            totalExecutions: executions.count,
            averageCompletion: averageCompletion,
            uniqueHabitsCount: uniqueHabits.count
        )
    }
}

struct EnhancedHabitExecutionRow: View {
    let execution: HabitExecution
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(execution.habit?.name ?? "不明な習慣")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if execution.daysChain > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("\(execution.daysChain)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                    
                    Text(execution.executedAt, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 8) {
                        CircularProgressView(
                            progress: Double(execution.completionPercentage) / 100.0,
                            size: 44,
                            lineWidth: 4,
                            color: colorForCompletionPercentage(execution.completionPercentage)
                        )
                        .overlay(
                            Text("\(execution.completionPercentage)%")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(colorForCompletionPercentage(execution.completionPercentage))
                        )
                    }
                    
                    ExecutionTypeLabel(type: execution.executionType)
                }
            }
            
            if let message = execution.message {
                Text("\"\(message.content)\"")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                    .lineLimit(3)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.vertical, 8)
    }
    
    private func colorForCompletionPercentage(_ percentage: Int) -> Color {
        switch percentage {
        case 90...100:
            return .green
        case 70..<90:
            return .orange
        default:
            return .red
        }
    }
}

struct HabitExecutionRow: View {
    let execution: HabitExecution
    
    var body: some View {
        EnhancedHabitExecutionRow(execution: execution)
    }
}

struct ExecutionTypeLabel: View {
    let type: ExecutionType
    
    var body: some View {
        Text(typeDisplayText)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(typeBackgroundColor)
            .foregroundColor(.white)
            .clipShape(Capsule())
    }
    
    private var typeDisplayText: String {
        switch type {
        case .direct:
            return "明示"
        case .partial:
            return "部分"
        case .inferred:
            return "推測"
        }
    }
    
    private var typeBackgroundColor: Color {
        switch type {
        case .direct:
            return .blue
        case .partial:
            return .orange
        case .inferred:
            return .gray
        }
    }
}

// MARK: - 補助ビューとデータ構造

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct DaySectionHeader: View {
    let dateString: String
    let executions: [HabitExecution]
    
    var body: some View {
        HStack {
            Text(dateString)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Spacer()
            
            Text("\(executions.count)件")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct CircularProgressView: View {
    let progress: Double
    let size: CGFloat
    let lineWidth: CGFloat
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
                .frame(width: size, height: size)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
        }
    }
}

struct ExecutionStats {
    let totalExecutions: Int
    let averageCompletion: Double
    let uniqueHabitsCount: Int
}

struct ExecutionStatsView: View {
    let stats: ExecutionStats
    let habits: [Habit]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("詳細統計")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)
                
                VStack(spacing: 16) {
                    StatRow(title: "総実行回数", value: "\(stats.totalExecutions)回")
                    StatRow(title: "平均完了率", value: "\(String(format: "%.1f", stats.averageCompletion))%")
                    StatRow(title: "実行した習慣数", value: "\(stats.uniqueHabitsCount)/\(habits.count)個")
                }
                .padding()
                .background(Color(UIColor.systemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct StatRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - DateFormatter Extensions

extension DateFormatter {
    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    static let dayWithWeekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日(E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
}

#Preview {
    HabitExecutionListView()
        .modelContainer(for: [Habit.self, Message.self, HabitExecution.self, HabitovaTask.self, ExecutionInference.self, HabitChain.self], inMemory: true)
}