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
        // 高速な存在チェック：制限付きクエリを使用
        var fetchDescriptor = FetchDescriptor<Habit>()
        fetchDescriptor.fetchLimit = 1 // 1件でも見つかればOK
        
        if let existingHabits = try? context.fetch(fetchDescriptor), !existingHabits.isEmpty {
            print("Mock data already exists (count: \(existingHabits.count))")
            return
        }
        
        print("Setting up mock data...")
        do {
            try loadAkiraUserData(modelContext: context)
            print("Mock data setup completed successfully")
        } catch {
            print("Failed to setup Akira mock data: \(error)")
        }
    }
    
    /// Akiraユーザーの12個の習慣と8個のチェーンを初期化
    func loadAkiraUserData(modelContext: ModelContext) throws {
        
        // 既存データをクリア（開発時のみ）
        try clearExistingData(modelContext: modelContext)
        
        // 1. 12個の習慣を作成
        let habits = createAkiraHabits()
        for habit in habits {
            modelContext.insert(habit)
        }
        
        // 2. 8個の習慣チェーンを作成
        let chains = createAkiraHabitChains(habits: habits)
        for chain in chains {
            modelContext.insert(chain)
        }
        
        // 3. HabitStepのサンプルを作成（ストレッチ習慣用）
        let steps = createSampleHabitSteps(habits: habits)
        for step in steps {
            modelContext.insert(step)
        }
        
        try modelContext.save()
        print("MockDataLoader: Akiraユーザーのモックデータを読み込み完了")
        print("- 習慣数: \(habits.count)個")
        print("- チェーン数: \(chains.count)個")
        print("- ステップ数: \(steps.count)個")
    }
    
    /// 開発時用：既存データクリア
    private func clearExistingData(modelContext: ModelContext) throws {
        // 既存の習慣とチェーンを削除
        let habitDescriptor = FetchDescriptor<Habit>()
        let existingHabits = try modelContext.fetch(habitDescriptor)
        for habit in existingHabits {
            modelContext.delete(habit)
        }
        
        let chainDescriptor = FetchDescriptor<HabitChain>()
        let existingChains = try modelContext.fetch(chainDescriptor)
        for chain in existingChains {
            modelContext.delete(chain)
        }
        
        let stepDescriptor = FetchDescriptor<HabitStep>()
        let existingSteps = try modelContext.fetch(stepDescriptor)
        for step in existingSteps {
            modelContext.delete(step)
        }
    }
    
    /// Akiraユーザーの12個の習慣を作成
    private func createAkiraHabits() -> [Habit] {
        var habits: [Habit] = []
        
        // 1. 朝7時起床
        let wakeupHabit = Habit(
            name: "朝7時起床",
            habitDescription: "平日、7時～7時15分に起床する",
            targetFrequency: "daily",
            importance: 0.7,
            hiddenParametersData: createHiddenParameters(
                rigidityLevel: 0.8,
                contextualTriggers: ["子どもの登園準備が必要になる時刻"],
                seasonalVariation: true,
                toleranceForFailure: 0.3,
                emotionalSignificance: 0.6,
                userRealisticExpectation: 0.8,
                externalPressure: 0.85,
                existingMomentum: 0.85
            )
        )
        wakeupHabit.id = UUID(uuidString: "6B29FC40-CA47-1067-B31D-00DD010662DA") ?? UUID()
        habits.append(wakeupHabit)
        
        // 2. 洗顔・身だしなみ
        let washingHabit = Habit(
            name: "洗顔・身だしなみ",
            habitDescription: "顔を洗う、歯を磨く、身支度",
            targetFrequency: "daily",
            importance: 0.55,
            hiddenParametersData: createHiddenParameters(
                rigidityLevel: 0.4,
                toleranceForFailure: 0.7,
                emotionalSignificance: 0.4,
                userRealisticExpectation: 0.5
            )
        )
        washingHabit.id = UUID(uuidString: "6B29FC41-CA47-1067-B31D-00DD010662DA") ?? UUID()
        habits.append(washingHabit)
        
        // 3. コーヒーボタンON
        let coffeeHabit = Habit(
            name: "コーヒーボタンON",
            habitDescription: "前夜に準備してあるコーヒーメーカーのボタンを押す",
            targetFrequency: "daily",
            importance: 0.65
        )
        coffeeHabit.id = UUID(uuidString: "6B29FC42-CA47-1067-B31D-00DD010662DA") ?? UUID()
        habits.append(coffeeHabit)
        
        // 4. ストレッチ（軽く）
        let stretchHabit = Habit(
            name: "ストレッチ（軽く）",
            habitDescription: "軽いストレッチ、可能であれば実施",
            targetFrequency: "daily",
            importance: 0.35,
            hiddenParametersData: createHiddenParameters(
                rigidityLevel: 0.3,
                toleranceForFailure: 0.8,
                emotionalSignificance: 0.4,
                userRealisticExpectation: 0.4
            )
        )
        stretchHabit.id = UUID(uuidString: "6B29FC43-CA47-1067-B31D-00DD010662DA") ?? UUID()
        habits.append(stretchHabit)
        
        // 5. 子どもの朝ごはん準備
        let breakfastHabit = Habit(
            name: "子どもの朝ごはん準備",
            habitDescription: "子どもの朝食を準備し、一緒に食べさせる",
            targetFrequency: "daily",
            importance: 0.95,
            hiddenParametersData: createHiddenParameters(
                rigidityLevel: 0.95,
                toleranceForFailure: 0.05,
                emotionalSignificance: 0.9,
                userRealisticExpectation: 0.8,
                externalPressure: 0.95
            )
        )
        breakfastHabit.id = UUID(uuidString: "6B29FC44-CA47-1067-B31D-00DD010662DA") ?? UUID()
        habits.append(breakfastHabit)
        
        // 6. 登園準備・送迎
        let sendoffHabit = Habit(
            name: "登園準備・送迎",
            habitDescription: "子どもの身支度をして、8時15分～8時45分に登園に送迎",
            targetFrequency: "daily",
            importance: 0.95,
            hiddenParametersData: createHiddenParameters(
                rigidityLevel: 0.95,
                toleranceForFailure: 0.05,
                emotionalSignificance: 0.9,
                externalPressure: 0.95
            )
        )
        sendoffHabit.id = UUID(uuidString: "6B29FC45-CA47-1067-B31D-00DD010662DA") ?? UUID()
        habits.append(sendoffHabit)
        
        // 7. 自分の朝食
        let myBreakfastHabit = Habit(
            name: "自分の朝食",
            habitDescription: "登園送迎後、自分の朝食を準備・摂取",
            targetFrequency: "daily",
            importance: 0.6
        )
        myBreakfastHabit.id = UUID(uuidString: "6B29FC46-CA47-1067-B31D-00DD010662DA") ?? UUID()
        habits.append(myBreakfastHabit)
        
        // 8. 仕事開始（9時30分）
        let workStartHabit = Habit(
            name: "仕事開始（9時30分）",
            habitDescription: "リモートワークの業務開始",
            targetFrequency: "weekdays",
            importance: 0.8
        )
        workStartHabit.id = UUID(uuidString: "6B29FC47-CA47-1067-B31D-00DD010662DA") ?? UUID()
        habits.append(workStartHabit)
        
        // 9. 子どもを寝かしつける
        let childSleepHabit = Habit(
            name: "子どもを寝かしつける",
            habitDescription: "22時頃に子どもを寝かしつける",
            targetFrequency: "daily",
            importance: 0.9,
            hiddenParametersData: createHiddenParameters(
                rigidityLevel: 0.9,
                toleranceForFailure: 0.1,
                emotionalSignificance: 0.95,
                externalPressure: 0.9
            )
        )
        childSleepHabit.id = UUID(uuidString: "6B29FC48-CA47-1067-B31D-00DD010662DA") ?? UUID()
        habits.append(childSleepHabit)
        
        // 10. 夜23時就寝（基本）
        let nightSleepHabit = Habit(
            name: "夜23時就寝（基本）",
            habitDescription: "23時に就寝する（基本的なリズム）",
            targetFrequency: "daily",
            importance: 0.75
        )
        nightSleepHabit.id = UUID(uuidString: "6B29FC49-CA47-1067-B31D-00DD010662DA") ?? UUID()
        habits.append(nightSleepHabit)
        
        // 11. アイドル配信視聴（週1回）
        let idolWatchHabit = Habit(
            name: "アイドル配信視聴（週1回）",
            habitDescription: "毎日開催されるアイドル配信のうち、週1回程度視聴する",
            targetFrequency: "weekly",
            importance: 0.8,
            hiddenParametersData: createHiddenParameters(
                emotionalSignificance: 0.9,
                existingMomentum: 0.95
            )
        )
        idolWatchHabit.id = UUID(uuidString: "6B29FC4A-CA47-1067-B31D-00DD010662DA") ?? UUID()
        habits.append(idolWatchHabit)
        
        // 12. 分割睡眠（配信ある日）
        let splitSleepHabit = Habit(
            name: "分割睡眠（配信ある日）",
            habitDescription: "23時就寝 → 25時起床 → 配信視聴（26時～27時半頃） → 28時に再就寝",
            targetFrequency: "weekly",
            importance: 0.5
        )
        splitSleepHabit.id = UUID(uuidString: "6B29FC4B-CA47-1067-B31D-00DD010662DA") ?? UUID()
        habits.append(splitSleepHabit)
        
        return habits
    }
    
    /// hiddenParametersをData形式で作成
    private func createHiddenParameters(
        rigidityLevel: Double? = nil,
        contextualTriggers: [String]? = nil,
        seasonalVariation: Bool? = nil,
        toleranceForFailure: Double? = nil,
        emotionalSignificance: Double? = nil,
        userRealisticExpectation: Double? = nil,
        externalPressure: Double? = nil,
        existingMomentum: Double? = nil
    ) -> Data? {
        
        let hiddenParams = Habit.HiddenParameters(
            rigidityLevel: rigidityLevel,
            contextualTriggers: contextualTriggers,
            seasonalVariation: seasonalVariation,
            toleranceForFailure: toleranceForFailure,
            emotionalSignificance: emotionalSignificance,
            userRealisticExpectation: userRealisticExpectation,
            externalPressure: externalPressure,
            existingMomentum: existingMomentum
        )
        
        return try? JSONEncoder().encode(hiddenParams)
    }
    
    /// Akiraユーザーの8個のチェーンを作成
    private func createAkiraHabitChains(habits: [Habit]) -> [HabitChain] {
        var chains: [HabitChain] = []
        
        // UUID文字列からHabitを検索するヘルパー
        func findHabit(byUUID uuidString: String) -> Habit? {
            let uuid = UUID(uuidString: uuidString)
            return habits.first { $0.id == uuid }
        }
        
        // 朝のチェーン（7個）
        
        // 1. 起床 → 洗顔
        if let wakeupHabit = findHabit(byUUID: "6B29FC40-CA47-1067-B31D-00DD010662DA"),
           let washingHabit = findHabit(byUUID: "6B29FC41-CA47-1067-B31D-00DD010662DA") {
            let chain1 = HabitChain(
                triggerHabits: [wakeupHabit.id],
                prerequisiteHabits: [String: Any]?(nil),
                nextHabitId: washingHabit.id,
                delayMinutes: 0,
                triggerCondition: TriggerCondition(type: "timeAfter", delayMinutes: 0, context: nil),
                confidence: 0.9
            )
            chains.append(chain1)
        }
        
        // 2. 洗顔 → コーヒー
        if let washingHabit = findHabit(byUUID: "6B29FC41-CA47-1067-B31D-00DD010662DA"),
           let coffeeHabit = findHabit(byUUID: "6B29FC42-CA47-1067-B31D-00DD010662DA") {
            let chain2 = HabitChain(
                triggerHabits: [washingHabit.id],
                prerequisiteHabits: [String: Any]?(nil),
                nextHabitId: coffeeHabit.id,
                delayMinutes: 5,
                triggerCondition: TriggerCondition(type: "timeAfter", delayMinutes: 5, context: nil),
                confidence: 0.85
            )
            chains.append(chain2)
        }
        
        // 3. コーヒー → ストレッチ（prerequisiteHabits付き）
        if let coffeeHabit = findHabit(byUUID: "6B29FC42-CA47-1067-B31D-00DD010662DA"),
           let stretchHabit = findHabit(byUUID: "6B29FC43-CA47-1067-B31D-00DD010662DA") {
            
            // prerequisiteHabits（前提条件習慣）を設定
            let prerequisiteHabits = [
                PrerequisiteHabit(
                    habitId: UUID(), // モック用の仮ID
                    habitName: "居間の机をどかす",
                    isMandatory: true,
                    estimatedTimeMinutes: 3,
                    description: "ストレッチスペースを確保するため机を移動"
                ),
                PrerequisiteHabit(
                    habitId: UUID(), // モック用の仮ID
                    habitName: "ストレッチマットを敷く",
                    isMandatory: false,
                    estimatedTimeMinutes: 2,
                    description: "快適なストレッチのための準備（可能であれば）"
                )
            ]
            
            let chain3 = HabitChain(
                triggerHabits: [coffeeHabit.id],
                prerequisiteHabits: prerequisiteHabits,
                nextHabitId: stretchHabit.id,
                delayMinutes: 5,
                triggerCondition: TriggerCondition(type: "timeAfter", delayMinutes: 5, context: nil),
                confidence: 0.6
            )
            chains.append(chain3)
        }
        
        // 4. ストレッチ → 子どもの朝ごはん
        if let stretchHabit = findHabit(byUUID: "6B29FC43-CA47-1067-B31D-00DD010662DA"),
           let breakfastHabit = findHabit(byUUID: "6B29FC44-CA47-1067-B31D-00DD010662DA") {
            let chain4 = HabitChain(
                triggerHabits: [stretchHabit.id],
                prerequisiteHabits: [String: Any]?(nil),
                nextHabitId: breakfastHabit.id,
                delayMinutes: 5,
                triggerCondition: TriggerCondition(type: "timeAfter", delayMinutes: 5, context: nil),
                confidence: 0.95
            )
            chains.append(chain4)
        }
        
        // 5. 子どもの朝ごはん → 登園準備
        if let breakfastHabit = findHabit(byUUID: "6B29FC44-CA47-1067-B31D-00DD010662DA"),
           let sendoffHabit = findHabit(byUUID: "6B29FC45-CA47-1067-B31D-00DD010662DA") {
            let chain5 = HabitChain(
                triggerHabits: [breakfastHabit.id],
                prerequisiteHabits: [String: Any]?(nil),
                nextHabitId: sendoffHabit.id,
                delayMinutes: 10,
                triggerCondition: TriggerCondition(type: "timeAfter", delayMinutes: 10, context: nil),
                confidence: 0.95
            )
            chains.append(chain5)
        }
        
        // 6. 登園送迎 → 自分の朝食
        if let sendoffHabit = findHabit(byUUID: "6B29FC45-CA47-1067-B31D-00DD010662DA"),
           let myBreakfastHabit = findHabit(byUUID: "6B29FC46-CA47-1067-B31D-00DD010662DA") {
            let chain6 = HabitChain(
                triggerHabits: [sendoffHabit.id],
                prerequisiteHabits: [String: Any]?(nil),
                nextHabitId: myBreakfastHabit.id,
                delayMinutes: 5,
                triggerCondition: TriggerCondition(type: "timeAfter", delayMinutes: 5, context: nil),
                confidence: 0.8
            )
            chains.append(chain6)
        }
        
        // 7. 自分の朝食 → 仕事開始
        if let myBreakfastHabit = findHabit(byUUID: "6B29FC46-CA47-1067-B31D-00DD010662DA"),
           let workStartHabit = findHabit(byUUID: "6B29FC47-CA47-1067-B31D-00DD010662DA") {
            let chain7 = HabitChain(
                triggerHabits: [myBreakfastHabit.id],
                prerequisiteHabits: [String: Any]?(nil),
                nextHabitId: workStartHabit.id,
                delayMinutes: 30,
                triggerCondition: TriggerCondition(type: "timeAfter", delayMinutes: 30, context: nil),
                confidence: 0.9
            )
            chains.append(chain7)
        }
        
        // 夜のチェーン（1個）
        
        // 8. 子どもを寝かしつける → 23時就寝
        if let childSleepHabit = findHabit(byUUID: "6B29FC48-CA47-1067-B31D-00DD010662DA"),
           let nightSleepHabit = findHabit(byUUID: "6B29FC49-CA47-1067-B31D-00DD010662DA") {
            let chain8 = HabitChain(
                triggerHabits: [childSleepHabit.id],
                prerequisiteHabits: [String: Any]?(nil),
                nextHabitId: nightSleepHabit.id,
                delayMinutes: 30,
                triggerCondition: TriggerCondition(type: "timeAfter", delayMinutes: 30, context: nil),
                confidence: 0.75
            )
            chains.append(chain8)
        }
        
        return chains
    }
    
    /// サンプルHabitStepを作成（ストレッチ習慣用）
    private func createSampleHabitSteps(habits: [Habit]) -> [HabitStep] {
        var steps: [HabitStep] = []
        
        // ストレッチ習慣を検索
        guard let stretchHabit = habits.first(where: { $0.name.contains("ストレッチ") }) else {
            return steps
        }
        
        // ステップ1: ストレッチマットを敷く
        let step1 = HabitStep(
            habitId: stretchHabit.id,
            stepNumber: 1,
            title: "ストレッチマットを敷く",
            stepDescription: "快適なストレッチのための準備",
            isOptional: true,
            estimatedTimeMinutes: 2
        )
        steps.append(step1)
        
        // ステップ2: 軽いウォーミングアップ
        let step2 = HabitStep(
            habitId: stretchHabit.id,
            stepNumber: 2,
            title: "軽いウォーミングアップ",
            stepDescription: "関節をゆっくり動かして体を準備",
            isOptional: false,
            estimatedTimeMinutes: 3
        )
        steps.append(step2)
        
        // ステップ3: ストレッチを実行
        let step3 = HabitStep(
            habitId: stretchHabit.id,
            stepNumber: 3,
            title: "ストレッチを実行",
            stepDescription: "上半身、下半身、背中を中心にした軽いストレッチ",
            isOptional: false,
            estimatedTimeMinutes: 8
        )
        steps.append(step3)
        
        // ステップ4: クールダウン
        let step4 = HabitStep(
            habitId: stretchHabit.id,
            stepNumber: 4,
            title: "クールダウン",
            stepDescription: "深呼吸しながら体を落ち着かせる",
            isOptional: true,
            estimatedTimeMinutes: 2
        )
        steps.append(step4)
        
        return steps
    }
    
}