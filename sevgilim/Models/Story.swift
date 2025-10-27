//
//  Story.swift
//  sevgilim
//

import Foundation
import FirebaseFirestore

enum StoryMediaType: String, Codable {
    case photo
    case video
}

struct Story: Identifiable, Codable {
    @DocumentID var id: String?
    let photoURL: String
    let thumbnailURL: String?
    let mediaType: StoryMediaType
    let duration: Double?
    let createdBy: String // userId
    let createdByName: String
    let createdByPhotoURL: String?
    let relationshipId: String
    let createdAt: Date
    var viewedBy: [String] // userId array
    var likedBy: [String]? // userId array - kim beğendi (optional - eski story'ler için)
    var likeTimestamps: [String: Date] // userId -> beğeni zamanı
    
    var isVideo: Bool {
        mediaType == .video
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case photoURL
        case thumbnailURL
        case mediaType
        case duration
        case createdBy
        case createdByName
        case createdByPhotoURL
        case relationshipId
        case createdAt
        case viewedBy
        case likedBy
        case likeTimestamps
    }
    
    // Codable init - likedBy yoksa boş array yap
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _id = try container.decode(DocumentID<String>.self, forKey: .id)
        photoURL = try container.decode(String.self, forKey: .photoURL)
        thumbnailURL = try container.decodeIfPresent(String.self, forKey: .thumbnailURL)
        mediaType = try container.decodeIfPresent(StoryMediaType.self, forKey: .mediaType) ?? .photo
        duration = try container.decodeIfPresent(Double.self, forKey: .duration)
        createdBy = try container.decode(String.self, forKey: .createdBy)
        createdByName = try container.decode(String.self, forKey: .createdByName)
        createdByPhotoURL = try container.decodeIfPresent(String.self, forKey: .createdByPhotoURL)
        relationshipId = try container.decode(String.self, forKey: .relationshipId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        viewedBy = try container.decode([String].self, forKey: .viewedBy)
        likedBy = try container.decodeIfPresent([String].self, forKey: .likedBy) ?? []
        likeTimestamps = try container.decodeIfPresent([String: Date].self, forKey: .likeTimestamps) ?? [:]
    }
    
    // Normal init
    init(photoURL: String, thumbnailURL: String?, mediaType: StoryMediaType, duration: Double?, createdBy: String, createdByName: String, createdByPhotoURL: String?, relationshipId: String, createdAt: Date, viewedBy: [String], likedBy: [String]?, likeTimestamps: [String: Date] = [:]) {
        self.photoURL = photoURL
        self.thumbnailURL = thumbnailURL
        self.mediaType = mediaType
        self.duration = duration
        self.createdBy = createdBy
        self.createdByName = createdByName
        self.createdByPhotoURL = createdByPhotoURL
        self.relationshipId = relationshipId
        self.createdAt = createdAt
        self.viewedBy = viewedBy
        self.likedBy = likedBy ?? []
        self.likeTimestamps = likeTimestamps
    }
    
    // 24 saat geçti mi?
    var isExpired: Bool {
        let expiryTime: TimeInterval = 24 * 60 * 60 // 24 saat
        return Date().timeIntervalSince(createdAt) > expiryTime
    }
    
    // Kaç saat önce paylaşıldı?
    var timeAgoText: String {
        let interval = Date().timeIntervalSince(createdAt)
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours) saat önce"
        } else if minutes > 0 {
            return "\(minutes) dakika önce"
        } else {
            return "Az önce"
        }
    }
    
    // Kalan süre (24 saatten)
    var remainingTime: String {
        let expiryTime: TimeInterval = 24 * 60 * 60
        let elapsed = Date().timeIntervalSince(createdAt)
        let remaining = expiryTime - elapsed
        
        if remaining <= 0 {
            return "Süresi doldu"
        }
        
        let hours = Int(remaining / 3600)
        let minutes = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours) saat kaldı"
        } else {
            return "\(minutes) dakika kaldı"
        }
    }
    
    // Bu user story'yi gördü mü?
    func isViewedBy(userId: String) -> Bool {
        return viewedBy.contains(userId)
    }
    
    // Bu user story'yi beğendi mi?
    func isLikedBy(userId: String) -> Bool {
        return likedBy?.contains(userId) ?? false
    }
    
    func likeTimestamp(for userId: String) -> Date? {
        return likeTimestamps[userId]
    }
}
