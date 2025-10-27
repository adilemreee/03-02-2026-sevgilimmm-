//
//  SecretVaultItem.swift
//  sevgilim
//

import Foundation
import FirebaseFirestore

enum SecretMediaType: String, Codable {
    case photo
    case video
}

struct SecretVaultItem: Identifiable, Codable {
    @DocumentID var id: String?
    var relationshipId: String
    var downloadURL: String
    var thumbnailURL: String?
    var storagePath: String
    var thumbnailPath: String?
    var type: SecretMediaType
    var title: String?
    var note: String?
    var uploadedBy: String
    var createdAt: Date
    var sizeInBytes: Int64?
    var duration: Double?
    var contentType: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case relationshipId
        case downloadURL
        case thumbnailURL
        case storagePath
        case thumbnailPath
        case type
        case title
        case note
        case uploadedBy
        case createdAt
        case sizeInBytes
        case duration
        case contentType
    }
    
    var formattedSize: String? {
        guard let bytes = sizeInBytes, bytes > 0 else { return nil }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    var isVideo: Bool {
        type == .video
    }
}
