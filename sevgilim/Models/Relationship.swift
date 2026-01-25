//
//  Relationship.swift
//  sevgilim
//

import Foundation
import FirebaseFirestore

struct Relationship: Identifiable, Codable {
    @DocumentID var id: String?
    var user1Id: String
    var user2Id: String
    var user1Name: String
    var user2Name: String
    var startDate: Date
    var createdAt: Date
    var themeColor: String? // Hex color code
    var chatClearedAt: [String: Date]? = nil
    
    enum CodingKeys: String, CodingKey {
        case id
        case user1Id
        case user2Id
        case user1Name
        case user2Name
        case startDate
        case createdAt
        case themeColor
        case chatClearedAt
    }
    
    func partnerName(for userId: String) -> String {
        return userId == user1Id ? user2Name : user1Name
    }
    
    func partnerId(for userId: String) -> String {
        return userId == user1Id ? user2Id : user1Id
    }
}
