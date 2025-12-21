//
//  HabitovaApp.swift
//  Habitova
//
//  Created by Akira Kobori on 2025/12/21.
//

import SwiftUI
import SwiftData
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
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    private func setupMockData() {
        let context = sharedModelContainer.mainContext
        MockDataLoader.shared.setupMockDataInContext(context)
    }
}
