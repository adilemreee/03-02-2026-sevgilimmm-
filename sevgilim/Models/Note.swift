//
//  Note.swift
//  sevgilim
//

import Foundation
import FirebaseFirestore

struct Note: Identifiable, Codable {
    var id: String? = nil
    var relationshipId: String
    var title: String
    var content: String
    var createdBy: String // userId
    var createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case relationshipId
        case title
        case content
        case createdBy
        case createdAt
        case updatedAt
    }
}
