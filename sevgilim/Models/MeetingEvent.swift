//
//  MeetingEvent.swift
//  sevgilim
//
//  Buluşma olayı modeli - İki partner'ın buluşma geçmişini takip eder
//

import Foundation
import FirebaseFirestore
import CoreLocation

struct MeetingEvent: Identifiable, Codable {
    @DocumentID var id: String?
    var relationshipId: String
    var user1Id: String
    var user2Id: String
    var startTime: Date
    var endTime: Date?                      // nil = hala devam ediyor
    var duration: TimeInterval?             // Saniye cinsinden süre
    var latitude: Double                    // Buluşma noktası
    var longitude: Double
    var placeName: String?                  // Buluşma yeri adı
    var address: String?                    // Adres bilgisi
    var isActive: Bool                      // Şu an aktif mi?
    var maxDistance: Double                 // Buluşma sırasındaki max mesafe (metre)
    var minDistance: Double                 // Buluşma sırasındaki min mesafe (metre)
    var notificationSent: Bool              // Bildirim gönderildi mi?
    var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case relationshipId
        case user1Id
        case user2Id
        case startTime
        case endTime
        case duration
        case latitude
        case longitude
        case placeName
        case address
        case isActive
        case maxDistance
        case minDistance
        case notificationSent
        case createdAt
    }
    
    // MARK: - Computed Properties
    
    /// CLLocationCoordinate2D olarak koordinat
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    /// CLLocation objesi
    var clLocation: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
    
    /// Firebase GeoPoint
    var geoPoint: GeoPoint {
        GeoPoint(latitude: latitude, longitude: longitude)
    }
    
    /// Buluşma süresi (hesaplanmış)
    var calculatedDuration: TimeInterval {
        if let duration = duration {
            return duration
        }
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }
    
    /// Formatlanmış süre
    var formattedDuration: String {
        let duration = calculatedDuration
        
        if duration < 60 {
            return "< 1 dk"
        } else if duration < 3600 {
            let minutes = Int(duration / 60)
            return "\(minutes) dakika"
        } else {
            let hours = Int(duration / 3600)
            let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
            if minutes == 0 {
                return "\(hours) saat"
            }
            return "\(hours) saat \(minutes) dk"
        }
    }
    
    /// Kısa formatlanmış süre
    var shortFormattedDuration: String {
        let duration = calculatedDuration
        
        if duration < 60 {
            return "<1dk"
        } else if duration < 3600 {
            let minutes = Int(duration / 60)
            return "\(minutes)dk"
        } else {
            let hours = Int(duration / 3600)
            let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
            if minutes == 0 {
                return "\(hours)sa"
            }
            return "\(hours)sa \(minutes)dk"
        }
    }
    
    /// Başlangıç tarihi formatlanmış
    var formattedStartDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        
        if Calendar.current.isDateInToday(startTime) {
            formatter.dateFormat = "HH:mm"
            return "Bugün \(formatter.string(from: startTime))"
        } else if Calendar.current.isDateInYesterday(startTime) {
            formatter.dateFormat = "HH:mm"
            return "Dün \(formatter.string(from: startTime))"
        } else {
            formatter.dateFormat = "d MMM yyyy, HH:mm"
            return formatter.string(from: startTime)
        }
    }
    
    /// Kısa tarih formatı
    var shortFormattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: startTime)
    }
    
    /// Buluşma durumu açıklaması
    var statusDescription: String {
        if isActive {
            return "Şu an birliktesiniz 💕"
        } else if let endTime = endTime {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "tr_TR")
            formatter.dateFormat = "HH:mm"
            return "Bitti: \(formatter.string(from: endTime))"
        }
        return ""
    }
    
    /// Konum açıklaması
    var locationDescription: String {
        if let placeName = placeName, !placeName.isEmpty {
            return placeName
        } else if let address = address, !address.isEmpty {
            return address
        }
        return "Konum bilgisi yok"
    }
    
    // MARK: - Initializers
    
    init(
        id: String? = nil,
        relationshipId: String,
        user1Id: String,
        user2Id: String,
        startTime: Date = Date(),
        endTime: Date? = nil,
        duration: TimeInterval? = nil,
        latitude: Double,
        longitude: Double,
        placeName: String? = nil,
        address: String? = nil,
        isActive: Bool = true,
        maxDistance: Double = 0,
        minDistance: Double = 0,
        notificationSent: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.relationshipId = relationshipId
        self.user1Id = user1Id
        self.user2Id = user2Id
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.latitude = latitude
        self.longitude = longitude
        self.placeName = placeName
        self.address = address
        self.isActive = isActive
        self.maxDistance = maxDistance
        self.minDistance = minDistance
        self.notificationSent = notificationSent
        self.createdAt = createdAt
    }
    
    /// CLLocation'dan oluştur
    init(
        relationshipId: String,
        user1Id: String,
        user2Id: String,
        location: CLLocation,
        placeName: String? = nil,
        address: String? = nil
    ) {
        self.id = nil
        self.relationshipId = relationshipId
        self.user1Id = user1Id
        self.user2Id = user2Id
        self.startTime = Date()
        self.endTime = nil
        self.duration = nil
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.placeName = placeName
        self.address = address
        self.isActive = true
        self.maxDistance = 0
        self.minDistance = 0
        self.notificationSent = false
        self.createdAt = Date()
    }
    
    // MARK: - Firebase Helpers
    
    /// Firestore'a yazılacak dictionary
    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "relationshipId": relationshipId,
            "user1Id": user1Id,
            "user2Id": user2Id,
            "startTime": Timestamp(date: startTime),
            "latitude": latitude,
            "longitude": longitude,
            "isActive": isActive,
            "maxDistance": maxDistance,
            "minDistance": minDistance,
            "notificationSent": notificationSent,
            "createdAt": Timestamp(date: createdAt),
            "geoPoint": GeoPoint(latitude: latitude, longitude: longitude)
        ]
        
        if let endTime = endTime { data["endTime"] = Timestamp(date: endTime) }
        if let duration = duration { data["duration"] = duration }
        if let placeName = placeName { data["placeName"] = placeName }
        if let address = address { data["address"] = address }
        
        return data
    }
    
    /// Firestore document'tan oluştur
    static func from(document: DocumentSnapshot) -> MeetingEvent? {
        guard let data = document.data() else { return nil }
        
        return MeetingEvent(
            id: document.documentID,
            relationshipId: data["relationshipId"] as? String ?? "",
            user1Id: data["user1Id"] as? String ?? "",
            user2Id: data["user2Id"] as? String ?? "",
            startTime: (data["startTime"] as? Timestamp)?.dateValue() ?? Date(),
            endTime: (data["endTime"] as? Timestamp)?.dateValue(),
            duration: data["duration"] as? TimeInterval,
            latitude: data["latitude"] as? Double ?? 0,
            longitude: data["longitude"] as? Double ?? 0,
            placeName: data["placeName"] as? String,
            address: data["address"] as? String,
            isActive: data["isActive"] as? Bool ?? false,
            maxDistance: data["maxDistance"] as? Double ?? 0,
            minDistance: data["minDistance"] as? Double ?? 0,
            notificationSent: data["notificationSent"] as? Bool ?? false,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }
    
    // MARK: - Mutating Methods
    
    /// Buluşmayı bitir
    mutating func end() {
        self.endTime = Date()
        self.isActive = false
        self.duration = Date().timeIntervalSince(startTime)
    }
    
    /// Mesafe güncelle
    mutating func updateDistance(_ distance: Double) {
        if distance > maxDistance {
            maxDistance = distance
        }
        if minDistance == 0 || distance < minDistance {
            minDistance = distance
        }
    }
}

// MARK: - Equatable
extension MeetingEvent: Equatable {
    static func == (lhs: MeetingEvent, rhs: MeetingEvent) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Hashable
extension MeetingEvent: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Sample Data
extension MeetingEvent {
    static var sampleData: [MeetingEvent] {
        [
            MeetingEvent(
                id: "1",
                relationshipId: "rel1",
                user1Id: "user1",
                user2Id: "user2",
                startTime: Date().addingTimeInterval(-7200), // 2 saat önce
                endTime: Date().addingTimeInterval(-3600),   // 1 saat önce
                duration: 3600,
                latitude: 41.0082,
                longitude: 28.9784,
                placeName: "Starbucks Kadıköy",
                address: "Kadıköy, İstanbul",
                isActive: false,
                maxDistance: 15,
                minDistance: 2,
                notificationSent: true
            ),
            MeetingEvent(
                id: "2",
                relationshipId: "rel1",
                user1Id: "user1",
                user2Id: "user2",
                startTime: Date().addingTimeInterval(-86400), // 1 gün önce
                endTime: Date().addingTimeInterval(-82800),
                duration: 3600,
                latitude: 41.0352,
                longitude: 28.9850,
                placeName: "Moda Sahil",
                address: "Moda, Kadıköy",
                isActive: false,
                maxDistance: 20,
                minDistance: 1,
                notificationSent: true
            )
        ]
    }
}
