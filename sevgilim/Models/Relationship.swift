//
//  Relationship.swift
//  sevgilim
//

import Foundation
import FirebaseFirestore
import CoreLocation

struct Relationship: Identifiable, Codable {
    @DocumentID var id: String?
    var user1Id: String
    var user2Id: String
    var user1Name: String
    var user2Name: String
    var startDate: Date
    var createdAt: Date
    var themeColor: String? // Hex color code
    var chatClearedAt: [String: Date]? = nil
    
    // MARK: - Konum & Buluşma Alanları
    var locationSharingEnabled: Bool?
    var totalMeetingCount: Int?
    var totalMeetingDuration: TimeInterval?  // Toplam buluşma süresi (saniye)
    var lastMeetingDate: Date?
    var lastMeetingLatitude: Double?
    var lastMeetingLongitude: Double?
    var lastMeetingPlaceName: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case user1Id
        case user2Id
        case user1Name
        case user2Name
        case startDate
        case createdAt
        case themeColor
        case chatClearedAt
        case locationSharingEnabled
        case totalMeetingCount
        case totalMeetingDuration
        case lastMeetingDate
        case lastMeetingLatitude
        case lastMeetingLongitude
        case lastMeetingPlaceName
    }
    
    func partnerName(for userId: String) -> String {
        return userId == user1Id ? user2Name : user1Name
    }
    
    func partnerId(for userId: String) -> String {
        return userId == user1Id ? user2Id : user1Id
    }
    
    // MARK: - Konum Computed Properties
    
    /// Son buluşma koordinatı
    var lastMeetingCoordinate: CLLocationCoordinate2D? {
        guard let lat = lastMeetingLatitude, let lon = lastMeetingLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    /// Son buluşma konumu CLLocation olarak
    var lastMeetingLocation: CLLocation? {
        guard let lat = lastMeetingLatitude, let lon = lastMeetingLongitude else { return nil }
        return CLLocation(latitude: lat, longitude: lon)
    }
    
    /// Toplam buluşma süresi formatlanmış
    var formattedTotalMeetingDuration: String {
        guard let duration = totalMeetingDuration, duration > 0 else { return "0 dakika" }
        
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours) saat \(minutes) dakika"
        } else {
            return "\(minutes) dakika"
        }
    }
    
    /// Son buluşma tarihi formatlanmış
    var formattedLastMeetingDate: String? {
        guard let date = lastMeetingDate else { return nil }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
            return "Bugün \(formatter.string(from: date))"
        } else if Calendar.current.isDateInYesterday(date) {
            formatter.dateFormat = "HH:mm"
            return "Dün \(formatter.string(from: date))"
        } else {
            formatter.dateFormat = "d MMM yyyy"
            return formatter.string(from: date)
        }
    }
}
