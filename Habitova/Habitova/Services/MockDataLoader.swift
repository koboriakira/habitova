//
//  MockDataLoader.swift
//  Habitova
//
//  Created by Claude on 2025/12/21.
//

import Foundation
import SwiftData

class MockDataLoader {
    static let shared = MockDataLoader()
    
    private init() {}
    
    struct MockUserData: Codable {
        let user: MockUser
        let interview: MockInterview
    }
    
    struct MockUser: Codable {
        let id: String
        let username: String
        let created_at: String
    }
    
    struct MockInterview: Codable {
        let id: String
        let version: Int
        let habits: [MockHabit]
        let habitChains: [MockChain]
        
        enum CodingKeys: String, CodingKey {
            case id, version, habits
            case habitChains = "habit_chains"
        }
    }
    
    struct MockHabit: Codable {
        let id: String
        let name: String
        let description: String
        let target_frequency: String
        let level: Int
        let completion_logic: MockCompletionLogic?
        let importance_inferred: Double?
        let estimated_time_minutes: Int?
        let hidden_parameters: MockHiddenParameters?
    }
    
    struct MockCompletionLogic: Codable {
        let type: String
        let value: Int
    }
    
    struct MockHiddenParameters: Codable {
        let rigidityLevel: Double?
        let contextualTriggers: [String]?
        let seasonalVariation: Bool?
        let toleranceForFailure: Double?
        let emotionalSignificance: Double?
        let userRealisticExpectation: Double?
        let externalPressure: Double?
        let existingMomentum: Double?
    }
    
    struct MockChain: Codable {
        let id: String
        let trigger_habits: [String]
        let next_habit_id: String
        let delay_minutes: Int
        let trigger_condition: MockTriggerCondition
    }
    
    struct MockTriggerCondition: Codable {
        let type: String
        let delayMinutes: Int?
    }
    
    func loadMockData() -> MockUserData? {
        guard let url = Bundle.main.url(forResource: "akira_mock_data", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("Failed to load akira_mock_data.json")
            return nil
        }
        
        do {
            let mockData = try JSONDecoder().decode(MockUserData.self, from: data)
            return mockData
        } catch {
            print("Failed to decode mock data: \(error)")
            return nil
        }
    }
    
    func setupMockDataInContext(_ context: ModelContext) {
        guard let mockData = loadMockData() else {
            print("Failed to load mock data")
            return
        }
        
        // Check if data already exists
        let fetchDescriptor = FetchDescriptor<Habit>()
        if let existingHabits = try? context.fetch(fetchDescriptor), !existingHabits.isEmpty {
            print("Mock data already exists")
            return
        }
        
        // Create habits
        var habitMap: [String: Habit] = [:]
        
        for mockHabit in mockData.interview.habits {
            let habit = Habit(
                id: UUID(uuidString: mockHabit.id) ?? UUID(),
                name: mockHabit.name,
                habitDescription: mockHabit.description,
                targetFrequency: mockHabit.target_frequency,
                level: mockHabit.level,
                importanceInferred: mockHabit.importance_inferred
            )
            
            // Set hidden parameters if available
            if let hiddenParams = mockHabit.hidden_parameters {
                let hiddenParameters = Habit.HiddenParameters(
                    rigidityLevel: hiddenParams.rigidityLevel,
                    contextualTriggers: hiddenParams.contextualTriggers,
                    seasonalVariation: hiddenParams.seasonalVariation,
                    toleranceForFailure: hiddenParams.toleranceForFailure,
                    emotionalSignificance: hiddenParams.emotionalSignificance,
                    userRealisticExpectation: hiddenParams.userRealisticExpectation,
                    externalPressure: hiddenParams.externalPressure,
                    existingMomentum: hiddenParams.existingMomentum
                )
                habit.hiddenParameters = hiddenParameters
            }
            
            habitMap[mockHabit.id] = habit
            context.insert(habit)
        }
        
        // Create habit chains
        for mockChain in mockData.interview.habitChains {
            let triggerHabitIds = mockChain.trigger_habits.compactMap { UUID(uuidString: $0) }
            let nextHabitId = UUID(uuidString: mockChain.next_habit_id) ?? UUID()
            
            let triggerCondition = TriggerCondition(
                type: mockChain.trigger_condition.type,
                delayMinutes: mockChain.trigger_condition.delayMinutes,
                context: nil
            )
            
            let habitChain = HabitChain(
                id: UUID(uuidString: mockChain.id) ?? UUID(),
                triggerHabits: triggerHabitIds,
                nextHabitId: nextHabitId,
                delayMinutes: mockChain.delay_minutes,
                triggerCondition: triggerCondition
            )
            
            context.insert(habitChain)
        }
        
        // Save the context
        do {
            try context.save()
            print("Mock data setup completed successfully")
        } catch {
            print("Failed to save mock data: \(error)")
        }
    }
}