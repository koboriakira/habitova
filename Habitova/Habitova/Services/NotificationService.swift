//
//  NotificationService.swift
//  Habitova
//
//  Created by Claude on 2025/12/22.
//

import Foundation
import UserNotifications
import SwiftData
import Combine

@MainActor
class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    @Published var isAuthorized = false
    @Published var scheduledNotifications: [ScheduledReminder] = []
    
    private override init() {
        super.init()
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            await MainActor.run {
                isAuthorized = granted
            }
            return granted
        } catch {
            print("通知許可リクエストエラー: \(error)")
            return false
        }
    }
    
    private func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Smart Reminder Scheduling
    
    func scheduleSmartReminders(for habits: [Habit]) async {
        guard isAuthorized else {
            print("通知が許可されていません")
            return
        }
        
        // 既存の通知をクリア
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        var newReminders: [ScheduledReminder] = []
        
        for habit in habits where !habit.isArchived {
            let reminders = await generateSmartReminders(for: habit)
            newReminders.append(contentsOf: reminders)
        }
        
        // 通知をスケジュール
        for reminder in newReminders {
            await scheduleNotification(for: reminder)
        }
        
        scheduledNotifications = newReminders
        print("スマートリマインダー \(newReminders.count)件をスケジュールしました")
    }
    
    private func generateSmartReminders(for habit: Habit) async -> [ScheduledReminder] {
        var reminders: [ScheduledReminder] = []
        let calendar = Calendar.current
        let now = Date()
        
        // 習慣の特性に基づいてリマインダータイミングを決定
        let reminderTimes = calculateOptimalReminderTimes(for: habit)
        
        for reminderTime in reminderTimes {
            // 今日から1週間分のリマインダーを生成
            for dayOffset in 0..<7 {
                guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
                guard shouldScheduleForDate(habit: habit, date: targetDate) else { continue }
                
                let reminderDateTime = calendar.date(
                    byAdding: .minute,
                    value: reminderTime.minutesFromMidnight,
                    to: calendar.startOfDay(for: targetDate)
                )
                
                guard let finalDateTime = reminderDateTime,
                      finalDateTime > now else { continue }
                
                let reminder = ScheduledReminder(
                    id: UUID(),
                    habitId: habit.id,
                    habitName: habit.name,
                    scheduledTime: finalDateTime,
                    reminderType: reminderTime.type,
                    message: generateReminderMessage(for: habit, type: reminderTime.type),
                    importance: habit.importance ?? 0.5
                )
                
                reminders.append(reminder)
            }
        }
        
        return reminders
    }
    
    private func calculateOptimalReminderTimes(for habit: Habit) -> [ReminderTime] {
        var times: [ReminderTime] = []
        let importance = habit.importance ?? 0.5
        
        // 習慣名から推定される時間帯を分析
        let timeOfDay = analyzeHabitTimeOfDay(habit.name)
        
        switch timeOfDay {
        case .morning:
            // 朝の習慣
            if importance > 0.8 {
                // 高重要度：前夜リマインダー + 当日リマインダー
                times.append(ReminderTime(minutesFromMidnight: 22 * 60, type: .preparationReminder)) // 22:00
                times.append(ReminderTime(minutesFromMidnight: 6 * 60 + 45, type: .executionReminder)) // 6:45
            } else {
                // 通常：当日のみ
                times.append(ReminderTime(minutesFromMidnight: 6 * 60 + 45, type: .executionReminder)) // 6:45
            }
            
        case .evening:
            // 夜の習慣
            times.append(ReminderTime(minutesFromMidnight: 21 * 60 + 30, type: .executionReminder)) // 21:30
            if importance > 0.8 {
                times.append(ReminderTime(minutesFromMidnight: 20 * 60, type: .preparationReminder)) // 20:00
            }
            
        case .work:
            // 仕事関連
            times.append(ReminderTime(minutesFromMidnight: 9 * 60, type: .executionReminder)) // 9:00
            
        case .weekly:
            // 週次習慣
            times.append(ReminderTime(minutesFromMidnight: 19 * 60, type: .executionReminder)) // 19:00 (金曜日)
            
        default:
            // その他：デフォルト時間
            times.append(ReminderTime(minutesFromMidnight: 12 * 60, type: .executionReminder)) // 12:00
        }
        
        return times
    }
    
    private func analyzeHabitTimeOfDay(_ habitName: String) -> HabitTimeOfDay {
        let name = habitName.lowercased()
        
        if name.contains("起床") || name.contains("朝") || name.contains("洗顔") || 
           name.contains("コーヒー") || name.contains("ストレッチ") || name.contains("朝ごはん") ||
           name.contains("登園") || name.contains("送迎") {
            return .morning
        } else if name.contains("寝かしつける") || name.contains("就寝") || name.contains("夜") {
            return .evening
        } else if name.contains("仕事") || name.contains("リモート") {
            return .work
        } else if name.contains("週") || name.contains("アイドル") || name.contains("配信") {
            return .weekly
        } else {
            return .general
        }
    }
    
    private func shouldScheduleForDate(habit: Habit, date: Date) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        
        switch habit.targetFrequency {
        case "daily":
            return true
        case "weekdays":
            return weekday >= 2 && weekday <= 6 // 月曜～金曜
        case "weekly":
            return weekday == 6 // 金曜日
        default:
            return true
        }
    }
    
    private func generateReminderMessage(for habit: Habit, type: ReminderType) -> String {
        let importance = habit.importance ?? 0.5
        
        switch type {
        case .preparationReminder:
            if importance > 0.8 {
                return "明日の「\(habit.name)」の準備をお忘れなく！"
            } else {
                return "明日の「\(habit.name)」の準備はいかがですか？"
            }
            
        case .executionReminder:
            if importance > 0.8 {
                return "「\(habit.name)」の時間です"
            } else {
                return "「\(habit.name)」はいかがですか？"
            }
            
        case .followUpReminder:
            return "「\(habit.name)」は完了しましたか？"
        }
    }
    
    private func scheduleNotification(for reminder: ScheduledReminder) async {
        let content = UNMutableNotificationContent()
        content.title = "Habitova"
        content.body = reminder.message
        content.sound = .default
        content.badge = 1
        
        // カスタムデータ
        content.userInfo = [
            "habitId": reminder.habitId.uuidString,
            "reminderType": reminder.reminderType.rawValue,
            "importance": reminder.importance
        ]
        
        // 時刻ベースのトリガー
        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminder.scheduledTime
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: reminder.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("通知スケジュールエラー: \(error)")
        }
    }
    
    // MARK: - Manual Reminders
    
    func scheduleImmediateReminder(for habit: Habit, message: String) async {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Habitova"
        content.body = message
        content.sound = .default
        content.userInfo = ["habitId": habit.id.uuidString]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("即座リマインダーエラー: \(error)")
        }
    }
    
    // MARK: - Management
    
    func removeAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        scheduledNotifications.removeAll()
    }
    
    func removeNotifications(for habitId: UUID) {
        let identifiersToRemove = scheduledNotifications
            .filter { $0.habitId == habitId }
            .map { $0.id.uuidString }
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        scheduledNotifications.removeAll { $0.habitId == habitId }
    }
}

// MARK: - Supporting Types

struct ScheduledReminder {
    let id: UUID
    let habitId: UUID
    let habitName: String
    let scheduledTime: Date
    let reminderType: ReminderType
    let message: String
    let importance: Double
}

struct ReminderTime {
    let minutesFromMidnight: Int
    let type: ReminderType
}

enum ReminderType: String, CaseIterable {
    case preparationReminder = "preparation"
    case executionReminder = "execution"
    case followUpReminder = "followup"
    
    var displayName: String {
        switch self {
        case .preparationReminder:
            return "準備リマインダー"
        case .executionReminder:
            return "実行リマインダー"
        case .followUpReminder:
            return "フォローアップ"
        }
    }
}

enum HabitTimeOfDay {
    case morning
    case evening
    case work
    case weekly
    case general
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // アプリがフォアグラウンドにある時も通知を表示
        completionHandler([.banner, .sound])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // 通知タップ時の処理
        let userInfo = response.notification.request.content.userInfo
        if let habitIdString = userInfo["habitId"] as? String,
           let habitId = UUID(uuidString: habitIdString) {
            
            // 習慣画面に遷移するなどの処理
            NotificationCenter.default.post(
                name: NSNotification.Name("HabitReminderTapped"),
                object: habitId
            )
        }
        
        completionHandler()
    }
}