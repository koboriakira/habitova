//
//  NotificationSettingsView.swift
//  Habitova
//
//  Created by Claude on 2025/12/22.
//

import SwiftUI
import SwiftData

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var habits: [Habit]
    @StateObject private var notificationService = NotificationService.shared
    @State private var showingTestNotification = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ヘッダー統計
                headerStatsView
                
                // メイン設定
                Form {
                    // 現在のリマインダー
                    currentRemindersSection
                    
                    // スマート機能設定
                    smartFeaturesSection
                    
                    // 管理機能
                    managementSection
                }
            }
            .navigationTitle("通知設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("更新") {
                        Task {
                            await refreshReminders()
                        }
                    }
                }
            }
            .onAppear {
                Task {
                    await loadInitialData()
                }
            }
        }
    }
    
    private var headerStatsView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                StatCard(
                    title: "予定済み",
                    value: "\(notificationService.scheduledNotifications.count)",
                    color: .blue
                )
                
                StatCard(
                    title: "アクティブ習慣",
                    value: "\(habits.filter { !$0.isArchived }.count)",
                    color: .green
                )
                
                StatCard(
                    title: "高重要度",
                    value: "\(habits.filter { ($0.importance ?? 0.0) > 0.8 }.count)",
                    color: .orange
                )
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    private var currentRemindersSection: some View {
        Section(header: Text("現在のリマインダー")) {
            if notificationService.scheduledNotifications.isEmpty {
                HStack {
                    Image(systemName: "bell.slash")
                        .foregroundColor(.secondary)
                    Text("スケジュール済みのリマインダーはありません")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                ForEach(groupedReminders, id: \.key) { groupItem in
                    DisclosureGroup(groupItem.key) {
                        ForEach(groupItem.value, id: \.id) { reminder in
                            ReminderRow(reminder: reminder)
                        }
                    }
                }
            }
        }
    }
    
    private var smartFeaturesSection: some View {
        Section(header: Text("スマート機能"), 
                footer: Text("習慣の重要度と時間帯に基づいて、最適なタイミングでリマインダーを自動生成します")) {
            
            Button(action: {
                Task {
                    await generateSmartReminders()
                }
            }) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.blue)
                    Text("スマートリマインダーを生成")
                    Spacer()
                    if !notificationService.scheduledNotifications.isEmpty {
                        Text("再生成")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .disabled(!notificationService.isAuthorized)
            
            Button(action: {
                Task {
                    await sendTestNotification()
                }
            }) {
                HStack {
                    Image(systemName: "testtube.2")
                        .foregroundColor(.green)
                    Text("テスト通知を送信")
                }
            }
            .disabled(!notificationService.isAuthorized)
        }
    }
    
    private var managementSection: some View {
        Section(header: Text("管理"), 
                footer: Text("すべてのリマインダーを削除すると、再度スマート生成が必要になります")) {
            
            Button(action: {
                notificationService.removeAllNotifications()
            }) {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                    Text("すべてのリマインダーを削除")
                        .foregroundColor(.red)
                }
            }
            .disabled(notificationService.scheduledNotifications.isEmpty)
            
            Button("システム設定を開く") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
        }
    }
    
    private var groupedReminders: [(key: String, value: [ScheduledReminder])] {
        let grouped = Dictionary(grouping: notificationService.scheduledNotifications) { reminder in
            DateFormatter.dayWithWeekday.string(from: reminder.scheduledTime)
        }
        return grouped.sorted { $0.key < $1.key }
    }
    
    // MARK: - Actions
    
    private func loadInitialData() async {
        // 通知権限の状態を更新
    }
    
    private func refreshReminders() async {
        let activeHabits = habits.filter { !$0.isArchived }
        await notificationService.scheduleSmartReminders(for: activeHabits)
    }
    
    private func generateSmartReminders() async {
        let activeHabits = habits.filter { !$0.isArchived }
        await notificationService.scheduleSmartReminders(for: activeHabits)
    }
    
    private func sendTestNotification() async {
        if let firstHabit = habits.first(where: { !$0.isArchived }) {
            await notificationService.scheduleImmediateReminder(
                for: firstHabit,
                message: "これはテスト通知です。通知が正常に動作しています！"
            )
        }
    }
}

struct ReminderRow: View {
    let reminder: ScheduledReminder
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(reminder.habitName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(reminder.scheduledTime, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                ReminderTypeLabel(type: reminder.reminderType)
                
                Spacer()
                
                ImportanceIndicator(importance: reminder.importance)
            }
            
            Text(reminder.message)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }
}

struct ReminderTypeLabel: View {
    let type: ReminderType
    
    var body: some View {
        Text(type.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(typeBackgroundColor)
            .foregroundColor(.white)
            .clipShape(Capsule())
    }
    
    private var typeBackgroundColor: Color {
        switch type {
        case .preparationReminder:
            return .orange
        case .executionReminder:
            return .blue
        case .followUpReminder:
            return .purple
        }
    }
}

// MARK: - Preview

#Preview {
    NotificationSettingsView()
        .modelContainer(for: [Habit.self], inMemory: true)
}