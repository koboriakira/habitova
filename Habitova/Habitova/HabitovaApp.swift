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
    @State private var isAppReady = false
    
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
            ZStack {
                if isAppReady {
                    ContentView()
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    SplashScreenView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: isAppReady)
            .task {
                await setupAppAsync()
                
                // 最低限の表示時間を確保（ユーザー体験向上）
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5秒
                
                withAnimation {
                    isAppReady = true
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
    
    /// 非同期でアプリの初期化を実行
    @MainActor
    private func setupAppAsync() async {
        // 即座に通知デリゲートを設定（同期）
        UNUserNotificationCenter.current().delegate = NotificationService.shared
        
        // バックグラウンドでその他の初期化を並行実行
        async let mockDataTask: Void = setupMockDataAsync()
        async let notificationTask: Void = setupNotificationsAsync()
        
        // 両方の完了を待つ
        _ = await (mockDataTask, notificationTask)
    }
    
    private func setupMockDataAsync() async {
        let container = sharedModelContainer
        await Task.detached {
            await MainActor.run {
                let context = container.mainContext
                MockDataLoader.shared.setupMockDataInContext(context)
            }
        }.value
    }
    
    private func setupNotificationsAsync() async {
        let context = sharedModelContainer.mainContext
        await setupInitialReminders(context: context)
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
