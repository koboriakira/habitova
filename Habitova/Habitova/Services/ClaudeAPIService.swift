//
//  ClaudeAPIService.swift
//  Habitova
//
//  Created by Claude on 2025/12/21.
//

import Foundation
import Combine
import SwiftData


// MARK: - API Structures (outside of class to avoid MainActor isolation)
struct ClaudeRequest: Codable, Sendable {
    let model: String
    let max_tokens: Int
    let messages: [ClaudeMessage]
    let system: String?
}

struct ClaudeMessage: Codable, Sendable {
    let role: String // "user" or "assistant"
    let content: String
}

struct ClaudeResponse: Codable, Sendable {
    let id: String
    let content: [ContentBlock]
    let model: String
    let usage: Usage?
    
    struct ContentBlock: Codable, Sendable {
        let type: String
        let text: String
    }
    
    struct Usage: Codable, Sendable {
        let input_tokens: Int
        let output_tokens: Int
    }
}

struct HabitAnalysisResult: Sendable {
    let extractedHabits: [InferredHabit]
    let proactiveQuestions: [String]
    let aiResponse: String
    let chainConsistencyCheck: ChainConsistencyCheck?
}

// InferredHabit, ExecutionType, ChainConsistencyCheck は ExecutionInference.swift で定義済み

@MainActor
class ClaudeAPIService: ObservableObject {
    static let shared = ClaudeAPIService()
    
    private var apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"
    
    private init() {
        // Keychainから取得、なければ.envファイル、それもなければ環境変数、それもなければ空文字
        if let keychainKey = KeychainService.shared.getAPIKey(), !keychainKey.isEmpty {
            self.apiKey = keychainKey
        } else if let envKey = EnvironmentLoader.shared.getClaudeAPIKey(), !envKey.isEmpty {
            self.apiKey = envKey
        } else if let processEnvKey = ProcessInfo.processInfo.environment["CLAUDE_API_KEY"], !processEnvKey.isEmpty {
            self.apiKey = processEnvKey
        } else {
            self.apiKey = ""
        }
    }
    
    /// APIキーを再読み込み（設定変更時に呼び出し）
    func reloadAPIKey() {
        if let keychainKey = KeychainService.shared.getAPIKey(), !keychainKey.isEmpty {
            self.apiKey = keychainKey
        } else if let envKey = EnvironmentLoader.shared.getClaudeAPIKey(), !envKey.isEmpty {
            self.apiKey = envKey
        } else if let processEnvKey = ProcessInfo.processInfo.environment["CLAUDE_API_KEY"], !processEnvKey.isEmpty {
            self.apiKey = processEnvKey
        } else {
            self.apiKey = ""
        }
    }
    
    /// APIキーが設定されているかチェック
    func isAPIKeyConfigured() -> Bool {
        return !apiKey.isEmpty
    }
    
    func analyzeUserInput(
        userInput: String,
        availableHabits: [Habit],
        conversationHistory: [Message] = []
    ) async throws -> HabitAnalysisResult {
        
        // システムプロンプトを構築
        let systemPrompt = buildSystemPrompt(availableHabits: availableHabits)
        
        // 会話履歴を含むメッセージを構築
        var messages: [ClaudeMessage] = []
        
        // 過去の会話履歴を追加（最近の5件まで）
        for message in conversationHistory.suffix(5) {
            messages.append(ClaudeMessage(
                role: message.sender == .user ? "user" : "assistant",
                content: message.content
            ))
        }
        
        // 現在のユーザー入力を追加
        messages.append(ClaudeMessage(role: "user", content: userInput))
        
        let request = ClaudeRequest(
            model: "claude-3-5-haiku-20241022",
            max_tokens: 1000,
            messages: messages,
            system: systemPrompt
        )
        
        // API呼び出し
        let response = try await makeAPICall(request: request)
        
        // レスポンスを解析
        return try parseAnalysisResponse(response: response, availableHabits: availableHabits)
    }
    
    private func buildSystemPrompt(availableHabits: [Habit]) -> String {
        let habitsDescription = availableHabits.map { habit in
            "- \(habit.name): \(habit.habitDescription)"
        }.joined(separator: "\n")
        
        return """
        あなたは習慣形成を支援するAIアシスタントです。ユーザーの報告から以下を分析してください：

        利用可能な習慣：
        \(habitsDescription)

        分析項目：
        1. 実行された習慣の特定（habit_id, execution_type: direct/partial/inferred, completion_percentage）
        2. チェーン整合性の確認（スキップされた習慣があるか）
        3. プロアクティブな質問の生成
        4. ユーザーへの簡潔で励ましの返答

        レスポンスはJSON形式で以下の構造で返してください：
        {
          "extracted_habits": [
            {
              "habit_id": "habit-xxx-001",
              "habit_name": "習慣名",
              "execution_type": "direct",
              "completion_percentage": 100,
              "confidence": 0.9
            }
          ],
          "proactive_questions": ["洗顔はしましたか？"],
          "ai_response": "おはようございます。朝7時起床とのことですね。素晴らしい。",
          "chain_consistency": {
            "detected_chain": ["habit-wakeup-001"],
            "expected_chain": ["habit-wakeup-001", "habit-washing-001", "habit-coffee-001"],
            "skipped_steps": ["habit-washing-001"],
            "inconsistency_level": 0.3
          }
        }
        """
    }
    
    private func makeAPICall(request: ClaudeRequest) async throws -> ClaudeResponse {
        guard !apiKey.isEmpty else {
            // デモ用のモックレスポンス
            return ClaudeResponse(
                id: "mock-response",
                content: [ClaudeResponse.ContentBlock(
                    type: "text",
                    text: """
                    {
                      "extracted_habits": [
                        {
                          "habit_id": "habit-wakeup-001",
                          "habit_name": "朝7時起床",
                          "execution_type": "direct",
                          "completion_percentage": 100,
                          "confidence": 0.9
                        }
                      ],
                      "proactive_questions": ["洗顔はしましたか？"],
                      "ai_response": "おはようございます。朝7時起床とのことですね。素晴らしい。",
                      "chain_consistency": {
                        "detected_chain": ["habit-wakeup-001"],
                        "expected_chain": ["habit-wakeup-001", "habit-washing-001", "habit-coffee-001"],
                        "skipped_steps": ["habit-washing-001"],
                        "inconsistency_level": 0.3
                      }
                    }
                    """
                )],
                model: "claude-3-5-sonnet-20241022",
                usage: nil
            )
        }
        
        // URLSession版API呼び出し
        let url = URL(string: baseURL)!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        let jsonData = try JSONEncoder().encode(request)
        urlRequest.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.networkError(NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
        }
        
        let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        return claudeResponse
    }
    
    private func parseAnalysisResponse(
        response: ClaudeResponse,
        availableHabits: [Habit]
    ) throws -> HabitAnalysisResult {
        
        guard let content = response.content.first?.text else {
            throw APIError.invalidResponse
        }
        
        // JSONレスポンスをパース
        guard let jsonData = content.data(using: .utf8) else {
            throw APIError.invalidJSON
        }
        
        do {
            let analysisJSON = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            
            // extracted_habitsをパース
            var extractedHabits: [InferredHabit] = []
            if let habitsArray = analysisJSON?["extracted_habits"] as? [[String: Any]] {
                for habitDict in habitsArray {
                    if let habitId = habitDict["habit_id"] as? String,
                       let habitName = habitDict["habit_name"] as? String,
                       let executionTypeStr = habitDict["execution_type"] as? String,
                       let completionPercentage = habitDict["completion_percentage"] as? Int,
                       let confidence = habitDict["confidence"] as? Double,
                       let executionType = ExecutionType(rawValue: executionTypeStr) {
                        
                        // UUIDの解析を試行し、失敗した場合は習慣名でマッチングを試す
                        let uuid: UUID
                        if let parsedUUID = UUID(uuidString: habitId) {
                            uuid = parsedUUID
                        } else if let matchedHabit = availableHabits.first(where: { $0.name == habitName }) {
                            uuid = matchedHabit.id
                            print("ClaudeAPIService: Matched habit by name: \(habitName) -> \(uuid)")
                        } else {
                            print("ClaudeAPIService: Failed to match habit: \(habitId) / \(habitName)")
                            continue
                        }
                        
                        let inferredHabit = InferredHabit(
                            habitId: uuid,
                            habitName: habitName,
                            executionType: executionType,
                            completionPercentage: completionPercentage,
                            confidence: confidence
                        )
                        extractedHabits.append(inferredHabit)
                    }
                }
            }
            
            // proactive_questionsをパース
            let proactiveQuestions = analysisJSON?["proactive_questions"] as? [String] ?? []
            
            // ai_responseをパース
            let aiResponse = analysisJSON?["ai_response"] as? String ?? "ありがとうございます。"
            
            // chain_consistencyをパース
            var chainConsistencyCheck: ChainConsistencyCheck?
            if let chainDict = analysisJSON?["chain_consistency"] as? [String: Any] {
                chainConsistencyCheck = parseChainConsistency(from: chainDict)
            }
            
            return HabitAnalysisResult(
                extractedHabits: extractedHabits,
                proactiveQuestions: proactiveQuestions,
                aiResponse: aiResponse,
                chainConsistencyCheck: chainConsistencyCheck
            )
            
        } catch {
            throw APIError.parsingError(error)
        }
    }
    
    /// デモ用モックレスポンス生成
    private func generateMockResponse(for userInput: String, availableHabits: [Habit]) -> String {
        print("ClaudeAPIService: generateMockResponse called for input: '\(userInput)'")
        print("ClaudeAPIService: Available habits: \(availableHabits.map { $0.name })")
        // ユーザー入力に基づいて最も関連性の高い習慣を推測
        let lowercaseInput = userInput.lowercased()
        var matchedHabits: [(Habit, Double)] = []
        
        for habit in availableHabits {
            var confidence: Double = 0.0
            let habitNameLower = habit.name.lowercased()
            let descriptionLower = habit.habitDescription.lowercased()
            
            // キーワードマッチング
            if lowercaseInput.contains("起き") && habitNameLower.contains("起床") {
                confidence = 0.9
            } else if (lowercaseInput.contains("洗顔") || lowercaseInput.contains("顔洗") || lowercaseInput.contains("身だしなみ")) && 
                      (habitNameLower.contains("洗顔") || habitNameLower.contains("身だしなみ")) {
                confidence = 0.9
            } else if lowercaseInput.contains("コーヒー") {
                if habitNameLower.contains("コーヒー") { confidence = 0.9 }
            } else if lowercaseInput.contains("ストレッチ") {
                if habitNameLower.contains("ストレッチ") { confidence = 0.9 }
            } else if lowercaseInput.contains("朝食") || lowercaseInput.contains("朝ごはん") {
                if habitNameLower.contains("朝ごはん") || habitNameLower.contains("朝食") { confidence = 0.9 }
            } else {
                // 部分マッチングを試行
                let inputWords = lowercaseInput.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)).filter { !$0.isEmpty }
                for word in inputWords {
                    if habitNameLower.contains(word) || descriptionLower.contains(word) {
                        confidence = max(confidence, 0.6)
                    }
                }
            }
            
            if confidence > 0.0 {
                matchedHabits.append((habit, confidence))
            }
        }
        
        // 上位1-2件を選択
        matchedHabits.sort { $0.1 > $1.1 }
        let selectedHabits = Array(matchedHabits.prefix(2))
        
        let extractedHabitsJSON = selectedHabits.map { habit, confidence in
            return """
            {
              "habit_id": "\(habit.id)",
              "habit_name": "\(habit.name)",
              "execution_type": "direct",
              "completion_percentage": 100,
              "confidence": \(confidence)
            }
            """
        }.joined(separator: ",\\n    ")
        
        let aiResponse = selectedHabits.isEmpty ? "ありがとうございます。" : 
            "\(selectedHabits[0].0.name)を実行されたんですね。素晴らしいです。"
        
        return """
        {
          "extracted_habits": [
            \(extractedHabitsJSON)
          ],
          "proactive_questions": ["他に実行した習慣はありますか？"],
          "ai_response": "\(aiResponse)",
          "chain_consistency": {
            "detected_chain": ["\(selectedHabits.first?.0.id.uuidString ?? "")"],
            "expected_chain": ["\(selectedHabits.first?.0.id.uuidString ?? "")"],
            "skipped_steps": [],
            "inconsistency_level": 0.0
          }
        }
        """
    }
    
    private func parseChainConsistency(from dict: [String: Any]) -> ChainConsistencyCheck? {
        guard let detectedChainStrings = dict["detected_chain"] as? [String],
              let expectedChainStrings = dict["expected_chain"] as? [String],
              let skippedStepsStrings = dict["skipped_steps"] as? [String],
              let inconsistencyLevel = dict["inconsistency_level"] as? Double else {
            return nil
        }
        
        let detectedChain = detectedChainStrings.compactMap { UUID(uuidString: $0) }
        let expectedChain = expectedChainStrings.compactMap { UUID(uuidString: $0) }
        let skippedSteps = skippedStepsStrings.compactMap { UUID(uuidString: $0) }
        let unreportedSteps = expectedChain.filter { !detectedChain.contains($0) }
        
        return ChainConsistencyCheck(
            detectedChain: detectedChain,
            expectedChain: expectedChain,
            skippedSteps: skippedSteps,
            unreportedSteps: unreportedSteps,
            inconsistencyLevel: inconsistencyLevel
        )
    }
}

enum APIError: Error, Sendable {
    case invalidResponse
    case invalidJSON
    case parsingError(Error)
    case networkError(Error)
}