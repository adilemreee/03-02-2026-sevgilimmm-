//
//  User.swift
//  sevgilim
//

import Foundation

struct NotificationPreferences: Codable, Equatable {
    var chat: Bool
    var memory: Bool
    var plan: Bool
    var specialDay: Bool
    
    static let `default` = NotificationPreferences()
    
    init(
        chat: Bool = true,
        memory: Bool = true,
        plan: Bool = true,
        specialDay: Bool = true
    ) {
        self.chat = chat
        self.memory = memory
        self.plan = plan
        self.specialDay = specialDay
    }
    
    nonisolated init(dictionary: [String: Any]) {
        self.chat = dictionary["chat"] as? Bool ?? true
        self.memory = dictionary["memory"] as? Bool ?? true
        self.plan = dictionary["plan"] as? Bool ?? true
        self.specialDay = dictionary["specialDay"] as? Bool ?? true
    }
    
    var firestoreData: [String: Bool] {
        [
            "chat": chat,
            "memory": memory,
            "plan": plan,
            "specialDay": specialDay
        ]
    }
}

struct User: Identifiable, Codable {
    var id: String?
    var email: String
    var name: String
    var profileImageURL: String?
    var relationshipId: String?
    var createdAt: Date
    var fcmTokens: [String]?
    var notificationPreferences: NotificationPreferences = .default
    var unreadNotificationCount: Int = 0
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case profileImageURL
        case relationshipId
        case createdAt
        case fcmTokens
        case notificationPreferences
        case unreadNotificationCount
    }
}
