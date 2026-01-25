//
//  UserLocation.swift
//  sevgilim
//
//  Kullanıcı konum verisi modeli - Firebase ile senkronize
//

import Foundation
import FirebaseFirestore
import CoreLocation

struct UserLocation: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var latitude: Double
    var longitude: Double
    var accuracy: Double                    // Konum hassasiyeti (metre)
    var speed: Double?                      // Hız (m/s)
    var heading: Double?                    // Yön (derece, kuzeye göre)
    var altitude: Double?                   // Rakım (metre)
    var isSharing: Bool                     // Konum paylaşımı aktif mi?
    var lastUpdated: Date                   // Son güncelleme zamanı
    var batteryLevel: Int?                  // Batarya seviyesi (0-100)
    var placeName: String?                  // Konum adı (cache)
    var address: String?                    // Adres bilgisi (cache)
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case latitude
        case longitude
        case accuracy
        case speed
        case heading
        case altitude
        case isSharing
        case lastUpdated
        case batteryLevel
        case placeName
        case address
    }
    
    // MARK: - Computed Properties
    
    /// CLLocation objesi olarak konum
    var clLocation: CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: altitude ?? 0,
            horizontalAccuracy: accuracy,
            verticalAccuracy: -1,
            course: heading ?? -1,
            speed: speed ?? -1,
            timestamp: lastUpdated
        )
    }
    
    /// CLLocationCoordinate2D olarak koordinat
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    /// Firebase GeoPoint olarak konum
    var geoPoint: GeoPoint {
        GeoPoint(latitude: latitude, longitude: longitude)
    }
    
    /// Hız formatlanmış (km/s)
    var formattedSpeed: String? {
        guard let speed = speed, speed >= 0 else { return nil }
        let kmh = speed * 3.6
        return String(format: "%.1f km/s", kmh)
    }
    
    /// Son güncelleme ne kadar önce
    var lastUpdatedAgo: String {
        let interval = Date().timeIntervalSince(lastUpdated)
        
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
    
    /// Konum güncel mi? (5 dakikadan eski değilse)
    var isRecent: Bool {
        Date().timeIntervalSince(lastUpdated) < 300 // 5 dakika
    }
    
    /// Batarya seviyesi durumu
    var batteryStatus: BatteryStatus? {
        guard let level = batteryLevel else { return nil }
        switch level {
        case 0...20: return .critical
        case 21...40: return .low
        case 41...60: return .medium
        case 61...80: return .good
        default: return .full
        }
    }
    
    enum BatteryStatus: String {
        case critical = "critical"
        case low = "low"
        case medium = "medium"
        case good = "good"
        case full = "full"
        
        var icon: String {
            switch self {
            case .critical: return "battery.0"
            case .low: return "battery.25"
            case .medium: return "battery.50"
            case .good: return "battery.75"
            case .full: return "battery.100"
            }
        }
        
        var color: String {
            switch self {
            case .critical: return "red"
            case .low: return "orange"
            case .medium: return "yellow"
            case .good, .full: return "green"
            }
        }
    }
    
    // MARK: - Initializers
    
    init(
        id: String? = nil,
        userId: String,
        latitude: Double,
        longitude: Double,
        accuracy: Double = 0,
        speed: Double? = nil,
        heading: Double? = nil,
        altitude: Double? = nil,
        isSharing: Bool = true,
        lastUpdated: Date = Date(),
        batteryLevel: Int? = nil,
        placeName: String? = nil,
        address: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.latitude = latitude
        self.longitude = longitude
        self.accuracy = accuracy
        self.speed = speed
        self.heading = heading
        self.altitude = altitude
        self.isSharing = isSharing
        self.lastUpdated = lastUpdated
        self.batteryLevel = batteryLevel
        self.placeName = placeName
        self.address = address
    }
    
    /// CLLocation'dan oluştur
    init(userId: String, location: CLLocation, isSharing: Bool = true, batteryLevel: Int? = nil) {
        self.id = nil
        self.userId = userId
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.accuracy = location.horizontalAccuracy
        self.speed = location.speed >= 0 ? location.speed : nil
        self.heading = location.course >= 0 ? location.course : nil
        self.altitude = location.altitude
        self.isSharing = isSharing
        self.lastUpdated = Date()
        self.batteryLevel = batteryLevel
        self.placeName = nil
        self.address = nil
    }
    
    // MARK: - Firebase Helpers
    
    /// Firestore'a yazılacak dictionary
    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "userId": userId,
            "latitude": latitude,
            "longitude": longitude,
            "accuracy": accuracy,
            "isSharing": isSharing,
            "lastUpdated": Timestamp(date: lastUpdated),
            "geoPoint": GeoPoint(latitude: latitude, longitude: longitude)
        ]
        
        if let speed = speed { data["speed"] = speed }
        if let heading = heading { data["heading"] = heading }
        if let altitude = altitude { data["altitude"] = altitude }
        if let batteryLevel = batteryLevel { data["batteryLevel"] = batteryLevel }
        if let placeName = placeName { data["placeName"] = placeName }
        if let address = address { data["address"] = address }
        
        return data
    }
    
    /// Firestore document'tan oluştur
    static func from(document: DocumentSnapshot) -> UserLocation? {
        guard let data = document.data() else { return nil }
        
        return UserLocation(
            id: document.documentID,
            userId: data["userId"] as? String ?? "",
            latitude: data["latitude"] as? Double ?? 0,
            longitude: data["longitude"] as? Double ?? 0,
            accuracy: data["accuracy"] as? Double ?? 0,
            speed: data["speed"] as? Double,
            heading: data["heading"] as? Double,
            altitude: data["altitude"] as? Double,
            isSharing: data["isSharing"] as? Bool ?? false,
            lastUpdated: (data["lastUpdated"] as? Timestamp)?.dateValue() ?? Date(),
            batteryLevel: data["batteryLevel"] as? Int,
            placeName: data["placeName"] as? String,
            address: data["address"] as? String
        )
    }
    
    // MARK: - Distance Calculation
    
    /// Başka bir konuma olan mesafeyi hesapla (metre)
    func distance(to other: UserLocation) -> Double {
        return clLocation.distance(from: other.clLocation)
    }
    
    /// CLLocation'a olan mesafeyi hesapla (metre)
    func distance(to location: CLLocation) -> Double {
        return clLocation.distance(from: location)
    }
    
    /// Başka bir konuma olan yönü hesapla (derece, kuzeye göre)
    func bearing(to other: UserLocation) -> Double {
        let lat1 = latitude * .pi / 180
        let lon1 = longitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let lon2 = other.longitude * .pi / 180
        
        let dLon = lon2 - lon1
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        
        var bearing = atan2(y, x) * 180 / .pi
        bearing = (bearing + 360).truncatingRemainder(dividingBy: 360)
        
        return bearing
    }
    
    /// Yön açıklaması (Kuzey, Güney, vs.)
    func bearingDescription(to other: UserLocation) -> String {
        let bearing = self.bearing(to: other)
        
        switch bearing {
        case 0..<22.5, 337.5...360: return "Kuzey"
        case 22.5..<67.5: return "Kuzeydoğu"
        case 67.5..<112.5: return "Doğu"
        case 112.5..<157.5: return "Güneydoğu"
        case 157.5..<202.5: return "Güney"
        case 202.5..<247.5: return "Güneybatı"
        case 247.5..<292.5: return "Batı"
        case 292.5..<337.5: return "Kuzeybatı"
        default: return ""
        }
    }
}

// MARK: - Equatable
extension UserLocation: Equatable {
    static func == (lhs: UserLocation, rhs: UserLocation) -> Bool {
        return lhs.userId == rhs.userId &&
               lhs.latitude == rhs.latitude &&
               lhs.longitude == rhs.longitude
    }
}

// MARK: - Hashable
extension UserLocation: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(userId)
        hasher.combine(latitude)
        hasher.combine(longitude)
    }
}
