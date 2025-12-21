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
    
    var body: some View {
        NavigationView {
            List {
                if executions.isEmpty {
                    ContentUnavailableView {
                        Label("実行記録なし", systemImage: "checkmark.circle")
                    } description: {
                        Text("まだ習慣の実行記録がありません")
                    }
                } else {
                    ForEach(executions) { execution in
                        HabitExecutionRow(execution: execution)
                    }
                }
            }
            .navigationTitle("実行記録")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct HabitExecutionRow: View {
    let execution: HabitExecution
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(execution.habit?.name ?? "不明な習慣")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(execution.executedAt, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(execution.completionPercentage)%")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(colorForCompletionPercentage(execution.completionPercentage))
                    
                    ExecutionTypeLabel(type: execution.executionType)
                }
            }
            
            if execution.daysChain > 0 {
                HStack {
                    Image(systemName: "link")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("連続\(execution.daysChain)日目")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                }
            }
            
            if let message = execution.message {
                Text("「\(message.content)」")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                    .lineLimit(2)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
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

#Preview {
    HabitExecutionListView()
        .modelContainer(for: [Habit.self, Message.self, HabitExecution.self, HabitovaTask.self, ExecutionInference.self, HabitChain.self], inMemory: true)
}