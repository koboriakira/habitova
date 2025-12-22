//
//  HabitovaApp.swift
//  Habitova
//
//  Created by Akira Kobori on 2025/12/21.
//

import SwiftUI
import SwiftData
import UserNotifications
// import ComposableArchitecture  // TCAパッケージ追加後にコメント解除

@main
struct HabitovaApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Habit.self,
            Message.self,
            HabitExecution.self,
            HabitovaTask.self,
            ExecutionInference.self,
            HabitChain.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    setupMockData()
                    setupNotifications()
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    private func setupMockData() {
        let context = sharedModelContainer.mainContext
        MockDataLoader.shared.setupMockDataInContext(context)
    }
    
    private func setupNotifications() {
        // 通知デリゲートを設定
        UNUserNotificationCenter.current().delegate = NotificationService.shared
        
        // スマートリマインダーの初期設定
        Task {
            let context = sharedModelContainer.mainContext
            await setupInitialReminders(context: context)
        }
    }
    
    @MainActor
    private func setupInitialReminders(context: ModelContext) async {
        let fetchDescriptor = FetchDescriptor<Habit>()
        do {
            let habits = try context.fetch(fetchDescriptor)
            let activeHabits = habits.filter { !$0.isArchived }
            
            // ユーザーが通知を許可済みで、既存のリマインダーがない場合のみ自動設定
            if await NotificationService.shared.requestAuthorization() && 
               NotificationService.shared.scheduledNotifications.isEmpty {
                await NotificationService.shared.scheduleSmartReminders(for: activeHabits)
            }
        } catch {
            print("初期リマインダー設定エラー: \(error)")
        }
    }
}
