//
//  WidgetDataManager.swift
//  sevgilim
//
//  Widget verilerini güncellemek için manager
//

import Foundation
import WidgetKit
import CoreLocation

/// Widget verilerini App Group üzerinden güncelleyen manager
final class WidgetDataManager {
    
    // MARK: - Singleton
    static let shared = WidgetDataManager()
    
    // MARK: - Constants
    private let appGroupId = "group.com.sevgilim.shared"
    
    // MARK: - Properties
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }
    
    // MARK: - Init
    private init() {}
    
    // MARK: - Relationship Data (Gün Sayacı Widget)
    
    /// İlişki başlangıç tarihini güncelle
    func updateRelationshipStartDate(_ date: Date) {
        sharedDefaults?.set(date, forKey: "relationship_start_date")
        reloadDayCounterWidget()
    }
    
    /// Kullanıcı isimlerini güncelle
    func updateUserNames(user1: String, user2: String) {
        sharedDefaults?.set(user1, forKey: "user1_name")
        sharedDefaults?.set(user2, forKey: "user2_name")
        reloadDayCounterWidget()
    }
    
    // MARK: - Partner Location Data
    
    /// Partner konumunu güncelle
    func updatePartnerLocation(
        name: String,
        locationName: String,
        distance: Double,
        isNearby: Bool,
        isMeeting: Bool,
        isSharing: Bool
    ) {
        let defaults = sharedDefaults
        defaults?.set(name, forKey: "partner_name")
        defaults?.set(locationName, forKey: "partner_location_name")
        defaults?.set(distance, forKey: "partner_distance")
        defaults?.set(Date(), forKey: "partner_last_updated")
        defaults?.set(isNearby, forKey: "partner_is_nearby")
        defaults?.set(isMeeting, forKey: "is_meeting_active")
        defaults?.set(isSharing, forKey: "partner_is_sharing")
        
        reloadPartnerLocationWidget()
    }
    
    /// Partner konumunu konum nesnesiyle güncelle
    func updatePartnerLocation(from location: CLLocation?, partnerName: String, placeName: String?, distance: Double?, isMeeting: Bool, isSharing: Bool) {
        let actualDistance = distance ?? 0
        let isNearby = actualDistance < 0.1 // 100 metre altı yakın
        
        updatePartnerLocation(
            name: partnerName,
            locationName: placeName ?? "Bilinmiyor",
            distance: actualDistance,
            isNearby: isNearby,
            isMeeting: isMeeting,
            isSharing: isSharing
        )
    }
    
    /// Buluşma durumunu güncelle
    func updateMeetingStatus(isMeeting: Bool, location: String? = nil) {
        sharedDefaults?.set(isMeeting, forKey: "is_meeting_active")
        if let location = location {
            sharedDefaults?.set(location, forKey: "partner_location_name")
        }
        reloadPartnerLocationWidget()
    }
    
    /// Partner paylaşım durumunu güncelle
    func updatePartnerSharingStatus(_ isSharing: Bool) {
        sharedDefaults?.set(isSharing, forKey: "partner_is_sharing")
        reloadPartnerLocationWidget()
    }
    
    // MARK: - Widget Reload
    
    /// Gün sayacı widget'ını yenile
    private func reloadDayCounterWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: "sevgilimWidget")
    }
    
    /// Partner konum widget'ını yenile
    private func reloadPartnerLocationWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: "PartnerLocationWidget")
    }
    
    /// Tüm widget'ları yenile
    func reloadAllWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // MARK: - Clear Data
    
    /// Widget verilerini temizle
    func clearAllData() {
        let keys = [
            "relationship_start_date",
            "user1_name",
            "user2_name",
            "partner_name",
            "partner_location_name",
            "partner_distance",
            "partner_last_updated",
            "partner_is_nearby",
            "is_meeting_active",
            "partner_is_sharing"
        ]
        
        for key in keys {
            sharedDefaults?.removeObject(forKey: key)
        }
        
        reloadAllWidgets()
    }
}

// MARK: - LocationService Extension
extension LocationService {
    
    /// Widget'a partner konum verisi gönder
    func updateWidgetWithPartnerLocation() {
        guard let partnerLocation = partnerLocation else {
            WidgetDataManager.shared.updatePartnerSharingStatus(false)
            return
        }
        
        let distance = distanceToPartner ?? 0
        let placeName = partnerLocation.placeName ?? "Bilinmiyor"
        let isSharing = partnerLocation.isSharing
        
        // Partner ismini RelationshipService'den al
        Task {
            let partnerName = await getPartnerName() ?? "Sevgilin"
            
            WidgetDataManager.shared.updatePartnerLocation(
                name: partnerName,
                locationName: placeName,
                distance: distance / 1000, // metre -> km
                isNearby: distance < 100,
                isMeeting: isMeetingActive,
                isSharing: isSharing
            )
        }
    }
    
    /// Partner ismini al
    private func getPartnerName() async -> String? {
        // Bu fonksiyon RelationshipService ile entegre edilmeli
        // Şimdilik UserDefaults'tan oku
        return UserDefaults(suiteName: "group.com.sevgilim.shared")?.string(forKey: "partner_name")
    }
}
