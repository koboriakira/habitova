//
//  Message.swift
//  Habitova
//
//  Created by Claude on 2025/12/21.
//

import Foundation
import SwiftData

enum MessageSender: String, Codable, CaseIterable, Sendable {
    case user = "user"
    case assistant = "assistant"
}

@Model
final class Message {
    var id: UUID
    var conversationId: UUID
    var senderRaw: String // MessageSenderのrawValue
    var content: String
    var createdAt: Date
    var relatedHabitsData: Data? // JSON encoded habit IDs
    var relatedChainsData: Data? // JSON encoded chain information
    var suggestedHabitsData: Data? // JSON encoded suggested habit IDs for trigger messages
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \HabitExecution.message)
    var habitExecutions: [HabitExecution] = []
    
    @Relationship(deleteRule: .cascade, inverse: \HabitovaTask.message)
    var tasks: [HabitovaTask] = []
    
    @Relationship(deleteRule: .cascade, inverse: \ExecutionInference.message)
    var executionInferences: [ExecutionInference] = []
    
    init(
        id: UUID = UUID(),
        conversationId: UUID,
        sender: MessageSender,
        content: String,
        relatedHabitsData: Data? = nil,
        relatedChainsData: Data? = nil,
        suggestedHabitsData: Data? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.senderRaw = sender.rawValue
        self.content = content
        self.createdAt = Date()
        self.relatedHabitsData = relatedHabitsData
        self.relatedChainsData = relatedChainsData
        self.suggestedHabitsData = suggestedHabitsData
    }
}

// MARK: - Computed Properties
extension Message {
    var sender: MessageSender {
        get { MessageSender(rawValue: senderRaw) ?? .user }
        set { senderRaw = newValue.rawValue }
    }
    
    var relatedHabitIds: [UUID]? {
        get {
            guard let data = relatedHabitsData else { return nil }
            return try? JSONDecoder().decode([UUID].self, from: data)
        }
        set {
            guard let newValue = newValue else {
                relatedHabitsData = nil
                return
            }
            relatedHabitsData = try? JSONEncoder().encode(newValue)
        }
    }
    
    var suggestedHabitIds: [UUID]? {
        get {
            guard let data = suggestedHabitsData else { return nil }
            return try? JSONDecoder().decode([UUID].self, from: data)
        }
        set {
            guard let newValue = newValue else {
                suggestedHabitsData = nil
                return
            }
            suggestedHabitsData = try? JSONEncoder().encode(newValue)
        }
    }
}