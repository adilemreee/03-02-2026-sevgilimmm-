//
//  Place.swift
//  sevgilim
//

import Foundation
import FirebaseFirestore

struct Place: Identifiable, Codable {
    var id: String? = nil
    var relationshipId: String
    var name: String
    var address: String?
    var latitude: Double
    var longitude: Double
    var note: String?
    var photoURLs: [String]?
    var date: Date
    var addedBy: String
    var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case relationshipId
        case name
        case address
        case latitude
        case longitude
        case note
        case photoURLs
        case date
        case addedBy
        case createdAt
    }
}
