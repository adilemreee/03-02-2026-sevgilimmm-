//
//  User.swift
//  sevgilim
//

import Foundation
import FirebaseFirestore
import CoreLocation

struct User: Identifiable, Codable {
    @DocumentID var id: String?
    var email: String
    var name: String
    var profileImageURL: String?
    var relationshipId: String?
    var createdAt: Date
    var fcmTokens: [String]?
    
    // MARK: - Konum Paylaşım Alanları
    var isLocationSharingEnabled: Bool?
    var lastLocationUpdate: Date?
    var lastKnownLatitude: Double?
    var lastKnownLongitude: Double?
    var lastKnownPlaceName: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case profileImageURL
        case relationshipId
        case createdAt
        case fcmTokens
        case isLocationSharingEnabled
        case lastLocationUpdate
        case lastKnownLatitude
        case lastKnownLongitude
        case lastKnownPlaceName
    }
    
    // MARK: - Computed Properties
    
    /// Son bilinen konum koordinatı
    var lastKnownCoordinate: CLLocationCoordinate2D? {
        guard let lat = lastKnownLatitude, let lon = lastKnownLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    /// Son bilinen konum CLLocation olarak
    var lastKnownLocation: CLLocation? {
        guard let lat = lastKnownLatitude, let lon = lastKnownLongitude else { return nil }
        return CLLocation(latitude: lat, longitude: lon)
    }
    
    /// Son konum güncelleme zamanı formatlanmış
    var lastSeenFormatted: String? {
        guard let lastUpdate = lastLocationUpdate else { return nil }
        
        let interval = Date().timeIntervalSince(lastUpdate)
        
        if interval < 60 {
            return "Az önce"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) dk önce"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) saat önce"
        } else {
            let days = Int(interval / 86400)
            return "\(days) gün önce"
        }
    }
}
