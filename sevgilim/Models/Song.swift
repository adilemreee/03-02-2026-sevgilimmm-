//
//  Song.swift
//  sevgilim
//

import Foundation
import FirebaseFirestore

struct Song: Identifiable, Codable {
    var id: String? = nil
    var relationshipId: String
    var title: String
    var artist: String
    var imageUrl: String?
    var spotifyLink: String?
    var appleMusicLink: String?
    var youtubeLink: String?
    var note: String?
    var addedBy: String
    var date: Date
    var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case relationshipId
        case title
        case artist
        case imageUrl
        case spotifyLink
        case appleMusicLink
        case youtubeLink
        case note
        case addedBy
        case date
        case createdAt
    }
}
