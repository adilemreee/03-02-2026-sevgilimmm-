//
//  User.swift
//  sevgilim
//

import Foundation
import FirebaseFirestore

struct User: Identifiable, Codable {
    @DocumentID var id: String?
    var email: String
    var name: String
    var profileImageURL: String?
    var relationshipId: String?
    var createdAt: Date
    var fcmTokens: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case profileImageURL
        case relationshipId
        case createdAt
        case fcmTokens
    }
}
