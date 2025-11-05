//
//  Surprise.swift
//  sevgilim
//

import Foundation
import FirebaseFirestore

struct Surprise: Identifiable, Codable {
    @DocumentID var id: String?
    var relationshipId: String
    var title: String
    var message: String
    var photoURL: String?
    var revealDate: Date // Açılış tarihi
    var createdBy: String // userId (kimin hazırladığı)
    var createdFor: String // userId (kimin için hazırlandığı)
    var createdAt: Date
    var isOpened: Bool // Açıldı mı?
    var openedAt: Date? // Açıldığı an
    var isManuallyHidden: Bool = false // Oluşturan tarafından elle gizlendi mi?
    
    enum CodingKeys: String, CodingKey {
        case id
        case relationshipId
        case title
        case message
        case photoURL
        case revealDate
        case createdBy
        case createdFor
        case createdAt
        case isOpened
        case openedAt
        case isManuallyHidden
    }
    
    init(
        id: String? = nil,
        relationshipId: String,
        title: String,
        message: String,
        photoURL: String? = nil,
        revealDate: Date,
        createdBy: String,
        createdFor: String,
        createdAt: Date,
        isOpened: Bool,
        openedAt: Date? = nil,
        isManuallyHidden: Bool = false
    ) {
        self.id = id
        self.relationshipId = relationshipId
        self.title = title
        self.message = message
        self.photoURL = photoURL
        self.revealDate = revealDate
        self.createdBy = createdBy
        self.createdFor = createdFor
        self.createdAt = createdAt
        self.isOpened = isOpened
        self.openedAt = openedAt
        self.isManuallyHidden = isManuallyHidden
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _id = try container.decode(DocumentID<String>.self, forKey: .id)
        relationshipId = try container.decode(String.self, forKey: .relationshipId)
        title = try container.decode(String.self, forKey: .title)
        message = try container.decode(String.self, forKey: .message)
        photoURL = try container.decodeIfPresent(String.self, forKey: .photoURL)
        revealDate = try container.decode(Date.self, forKey: .revealDate)
        createdBy = try container.decode(String.self, forKey: .createdBy)
        createdFor = try container.decode(String.self, forKey: .createdFor)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isOpened = try container.decodeIfPresent(Bool.self, forKey: .isOpened) ?? false
        openedAt = try container.decodeIfPresent(Date.self, forKey: .openedAt)
        isManuallyHidden = try container.decodeIfPresent(Bool.self, forKey: .isManuallyHidden) ?? false
    }
    
    // Sürprizin kilitli olup olmadığını kontrol et
    var isLocked: Bool {
        if isManuallyHidden {
            return true
        }
        guard !isOpened else { return false }
        return Date() < revealDate
    }
    
    // Geri sayım için kalan süreyi hesapla
    var timeRemaining: TimeInterval {
        return max(0, revealDate.timeIntervalSince(Date()))
    }
    
    // Süre doldu mu?
    var shouldReveal: Bool {
        guard !isOpened else { return false }
        if isManuallyHidden {
            return false
        }
        return Date() >= revealDate
    }
}
