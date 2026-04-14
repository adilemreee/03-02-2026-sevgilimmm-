//
//  Movie.swift
//  sevgilim
//

import Foundation
import FirebaseFirestore

struct Movie: Identifiable, Codable {
    var id: String? = nil
    var relationshipId: String
    var title: String
    var watchedDate: Date
    var rating: Int? // 1-5 stars
    var notes: String?
    var posterURL: String?
    var addedBy: String // userId
    var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case relationshipId
        case title
        case watchedDate
        case rating
        case notes
        case posterURL
        case addedBy
        case createdAt
    }
}
