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
    @DocumentID var id: String?
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
    var mediaType: PhotoMediaType?
    var duration: Double?
    
    var isVideo: Bool {
        (mediaType ?? .photo) == .video
    }
    
    var displayThumbnailURL: String {
        thumbnailURL ?? imageURL
    }
    
    var resolvedMediaType: PhotoMediaType {
        mediaType ?? .photo
    }
}
