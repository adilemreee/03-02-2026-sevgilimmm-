//
//  Photo.swift
//  sevgilim
//

import Foundation
import FirebaseFirestore

enum PhotoMediaType: String, Codable {
    case photo
    case video
}

struct Photo: Identifiable, Codable {
    var id: String?
    var relationshipId: String
    var imageURL: String
    var thumbnailURL: String?
    var videoURL: String?
    var title: String?
    var date: Date
    var location: String?
    var tags: [String]?
    var uploadedBy: String // userId
    var createdAt: Date
    var mediaType: PhotoMediaType
    var duration: Double?
    
    var isVideo: Bool {
        mediaType == .video
    }
    
    var displayThumbnailURL: String {
        thumbnailURL ?? imageURL
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case relationshipId
        case imageURL
        case thumbnailURL
        case videoURL
        case title
        case date
        case location
        case tags
        case uploadedBy
        case createdAt
        case mediaType
        case duration
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        relationshipId = try container.decode(String.self, forKey: .relationshipId)
        imageURL = try container.decode(String.self, forKey: .imageURL)
        thumbnailURL = try container.decodeIfPresent(String.self, forKey: .thumbnailURL)
        videoURL = try container.decodeIfPresent(String.self, forKey: .videoURL)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        date = try container.decode(Date.self, forKey: .date)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        uploadedBy = try container.decode(String.self, forKey: .uploadedBy)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        mediaType = try container.decodeIfPresent(PhotoMediaType.self, forKey: .mediaType) ?? .photo
        duration = try container.decodeIfPresent(Double.self, forKey: .duration)
    }
    
    init(
        id: String? = nil,
        relationshipId: String,
        imageURL: String,
        thumbnailURL: String?,
        videoURL: String?,
        title: String?,
        date: Date,
        location: String?,
        tags: [String]?,
        uploadedBy: String,
        createdAt: Date,
        mediaType: PhotoMediaType,
        duration: Double? = nil
    ) {
        self.id = id
        self.relationshipId = relationshipId
        self.imageURL = imageURL
        self.thumbnailURL = thumbnailURL
        self.videoURL = videoURL
        self.title = title
        self.date = date
        self.location = location
        self.tags = tags
        self.uploadedBy = uploadedBy
        self.createdAt = createdAt
        self.mediaType = mediaType
        self.duration = duration
    }
}
