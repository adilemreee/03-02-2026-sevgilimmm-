//
//  Memory.swift
//  sevgilim
//

import Foundation
import FirebaseFirestore

struct Memory: Identifiable, Codable {
    @DocumentID var id: String?
    var relationshipId: String
    var title: String
    var content: String
    var date: Date
    var photoURLs: [String]
    var location: String?
    var tags: [String]?
    var createdBy: String
    var createdAt: Date
    var likes: [String]
    var comments: [Comment]
    
    // Geriye uyumluluk: eski photoURL alanını okumak için
    private var photoURL: String?
    
    // Computed property - tüm fotoğrafları döndür (photoURLs + eski photoURL)
    var allPhotoURLs: [String] {
        if !photoURLs.isEmpty {
            return photoURLs
        } else if let url = photoURL {
            return [url]
        }
        return []
    }
    
    // Computed property - ilk fotoğrafı döndür
    var firstPhotoURL: String? {
        allPhotoURLs.first
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case relationshipId
        case title
        case content
        case date
        case photoURL
        case photoURLs
        case location
        case tags
        case createdBy
        case createdAt
        case likes
        case comments
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // NOT: id'yi DECODE ETMİYORUZ! @DocumentID otomatik halleder
        _id = try container.decode(DocumentID<String>.self, forKey: .id)
        
        relationshipId = try container.decode(String.self, forKey: .relationshipId)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        date = try container.decode(Date.self, forKey: .date)
        
        // Geriye uyumluluk: photoURLs veya photoURL
        if let urls = try? container.decode([String].self, forKey: .photoURLs), !urls.isEmpty {
            photoURLs = urls
            photoURL = nil
        } else {
            photoURLs = []
            photoURL = try container.decodeIfPresent(String.self, forKey: .photoURL)
        }
        
        location = try container.decodeIfPresent(String.self, forKey: .location)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        createdBy = try container.decode(String.self, forKey: .createdBy)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        likes = try container.decodeIfPresent([String].self, forKey: .likes) ?? []
        comments = try container.decodeIfPresent([Comment].self, forKey: .comments) ?? []
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(relationshipId, forKey: .relationshipId)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encode(date, forKey: .date)
        
        // Her iki alanı da kaydet (geriye uyumluluk)
        let allPhotos = photoURLs.isEmpty ? (photoURL.map { [$0] } ?? []) : photoURLs
        try container.encode(allPhotos, forKey: .photoURLs)
        try container.encodeIfPresent(allPhotos.first, forKey: .photoURL)
        
        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(tags, forKey: .tags)
        try container.encode(createdBy, forKey: .createdBy)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(likes, forKey: .likes)
        try container.encode(comments, forKey: .comments)
    }
    
    // Yeni anı oluşturmak için manuel init
    init(
        id: String? = nil,
        relationshipId: String,
        title: String,
        content: String,
        date: Date,
        photoURLs: [String] = [],
        location: String? = nil,
        tags: [String]? = nil,
        createdBy: String,
        createdAt: Date,
        likes: [String] = [],
        comments: [Comment] = []
    ) {
        self._id = DocumentID(wrappedValue: id)
        self.relationshipId = relationshipId
        self.title = title
        self.content = content
        self.date = date
        self.photoURLs = photoURLs
        self.photoURL = nil
        self.location = location
        self.tags = tags
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.likes = likes
        self.comments = comments
    }
}

struct Comment: Identifiable, Codable {
    var id: String = UUID().uuidString
    var userId: String
    var userName: String
    var text: String
    var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case userName
        case text
        case createdAt
    }
}


