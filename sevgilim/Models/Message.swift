//
//  Message.swift
//  sevgilim
//

import Foundation
import FirebaseFirestore

struct Message: Identifiable, Codable {
    var id: String? = nil
    var relationshipId: String
    var senderId: String
    var senderName: String
    var text: String
    var imageURL: String?
    var storyImageURL: String? // Story yanıtı için story resmi
    var timestamp: Date
    var isRead: Bool
    var readAt: Date?
    var reactions: [String: [String]]?
    var deletedForUserIds: [String]?
    var isDeletedForEveryone: Bool?
    var deletedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case relationshipId
        case senderId
        case senderName
        case text
        case imageURL
        case storyImageURL
        case timestamp
        case isRead
        case readAt
        case reactions
        case deletedForUserIds
        case isDeletedForEveryone
        case deletedAt
    }
}

// MARK: - Typing Indicator Model
struct TypingIndicator: Codable {
    var userId: String
    var userName: String
    var isTyping: Bool
    var timestamp: Date
}

// MARK: - Message Helpers
extension Message {
    var isGloballyDeleted: Bool {
        isDeletedForEveryone ?? false
    }
    
    func isDeletedForUser(_ userId: String) -> Bool {
        deletedForUserIds?.contains(userId) ?? false
    }
    
    func reactionsSorted() -> [(emoji: String, users: [String])] {
        guard let reactions = reactions else { return [] }
        return reactions
            .map { (emoji: $0.key, users: $0.value) }
            .filter { !$0.users.isEmpty }
            .sorted { lhs, rhs in
                if lhs.users.count == rhs.users.count {
                    return lhs.emoji < rhs.emoji
                }
                return lhs.users.count > rhs.users.count
            }
    }
    
    func userHasReaction(_ emoji: String, userId: String) -> Bool {
        reactions?[emoji]?.contains(userId) ?? false
    }
    
    func isVisible(for userId: String, clearedAfter date: Date) -> Bool {
        if timestamp < date { return false }
        if isDeletedForUser(userId) { return false }
        return true
    }
}
