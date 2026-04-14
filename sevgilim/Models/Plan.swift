//
//  Plan.swift
//  sevgilim
//

import Foundation
import FirebaseFirestore

struct Plan: Identifiable, Codable {
    var id: String? = nil
    var relationshipId: String
    var title: String
    var description: String?
    var date: Date?
    var isCompleted: Bool
    var reminderEnabled: Bool
    var createdBy: String // userId
    var createdAt: Date
    var completedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case relationshipId
        case title
        case description
        case date
        case isCompleted
        case reminderEnabled
        case createdBy
        case createdAt
        case completedAt
    }
}
