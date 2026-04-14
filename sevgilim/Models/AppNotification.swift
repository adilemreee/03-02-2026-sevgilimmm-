//
//  AppNotification.swift
//  sevgilim
//

import Foundation
import FirebaseFirestore

struct AppNotification: Identifiable, Codable {
    var id: String? = nil
    var userId: String
    var relationshipId: String?
    var type: String
    var title: String
    var body: String
    var metadata: [String: String]
    var isRead: Bool
    var createdAt: Date
    var readAt: Date?
    var deliveryState: String?
    var tokenCount: Int?
    var successCount: Int?
    var failureCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case relationshipId
        case type
        case title
        case body
        case metadata
        case isRead
        case createdAt
        case readAt
        case deliveryState
        case tokenCount
        case successCount
        case failureCount
    }
    
    var normalizedType: String {
        type.lowercased()
    }
    
    var iconName: String {
        switch normalizedType {
        case "message_new", "story_reply", "inactive_couple_nudge":
            return "bubble.left.and.text.bubble.right.fill"
        case "surprise_new", "surprise_reveal_due", "surprise_opened", "special_day_surprise_missing":
            return "gift.fill"
        case "special_day_upcoming", "special_day_new", "special_day_update", "special_day_reminder":
            return "calendar.badge.heart"
        case "special_day_plan_missing", "plan_new", "plan_update", "plan_reminder", "plan_tomorrow", "plan_completed":
            return "calendar.badge.plus"
        case "movie_new", "movie_night":
            return "film"
        case "note_new", "note_shared", "note_update":
            return "note.text"
        case "photo_new", "photo_added":
            return "photo.on.rectangle"
        case "song_new", "song_shared":
            return "music.note.list"
        case "place_new", "place_recommendation":
            return "mappin.circle"
        case "secret_vault_new", "secret_vault_alert":
            return "lock.square.stack"
        case "memory_like":
            return "heart.fill"
        case "memory_comment":
            return "bubble.left.fill"
        case "on_this_day_memory":
            return "clock.arrow.circlepath"
        case "memory_new":
            return "sparkles.rectangle.stack"
        case "story_new", "story_like":
            return "camera.circle"
        case "mood_update":
            return "face.smiling"
        default:
            return "bell.fill"
        }
    }
    
    var thumbnailURL: String? {
        metadata["thumbnailURL"] ??
        metadata["imageURL"] ??
        metadata["photoURL"] ??
        metadata["storyImageURL"]
    }
    
    var deliveryStateLabel: String? {
        switch deliveryState?.lowercased() {
        case "sent", nil:
            return nil
        case "inbox_only":
            return "Sadece geçmişe kaydedildi"
        case "failed":
            return "Cihaza gönderilemedi"
        case "queued":
            return "Gönderim bekliyor"
        default:
            return deliveryState
        }
    }
}
