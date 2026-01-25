//
//  LocationSharingSettings.swift
//  sevgilim
//
//  Konum paylaşım ayarları modeli
//

import Foundation

struct LocationSharingSettings: Codable, Equatable {
    var isEnabled: Bool
    var updateFrequency: UpdateFrequency
    var proximityThreshold: Double          // Metre cinsinden yakınlık eşiği
    var notificationsEnabled: Bool          // Buluşma bildirimleri
    var sharingMode: SharingMode
    var showBatteryLevel: Bool              // Batarya seviyesini göster
    var showSpeed: Bool                     // Hız bilgisini göster
    var showLastSeen: Bool                  // Son görülme zamanını göster
    var meetingDetectionEnabled: Bool       // Otomatik buluşma algılama
    var minimumMeetingDuration: TimeInterval // Minimum buluşma süresi (saniye)
    
    // MARK: - Enums
    
    enum UpdateFrequency: String, Codable, CaseIterable {
        case realtime = "realtime"          // 5 saniye
        case normal = "normal"              // 30 saniye
        case batterySaver = "batterySaver"  // 2 dakika
        
        var interval: TimeInterval {
            switch self {
            case .realtime: return 5
            case .normal: return 30
            case .batterySaver: return 120
            }
        }
        
        var displayName: String {
            switch self {
            case .realtime: return "Gerçek Zamanlı"
            case .normal: return "Normal"
            case .batterySaver: return "Pil Tasarrufu"
            }
        }
        
        var description: String {
            switch self {
            case .realtime: return "Her 5 saniyede güncelle (yüksek pil tüketimi)"
            case .normal: return "Her 30 saniyede güncelle (dengeli)"
            case .batterySaver: return "Her 2 dakikada güncelle (düşük pil tüketimi)"
            }
        }
        
        var icon: String {
            switch self {
            case .realtime: return "bolt.fill"
            case .normal: return "clock.fill"
            case .batterySaver: return "battery.100"
            }
        }
    }
    
    enum SharingMode: String, Codable, CaseIterable {
        case always = "always"                  // Her zaman paylaş
        case whenUsingApp = "whenUsingApp"      // Uygulama açıkken
        case manual = "manual"                  // Manuel kontrol
        
        var displayName: String {
            switch self {
            case .always: return "Her Zaman"
            case .whenUsingApp: return "Uygulama Açıkken"
            case .manual: return "Manuel"
            }
        }
        
        var description: String {
            switch self {
            case .always: return "Arka planda bile konum paylaşılır"
            case .whenUsingApp: return "Sadece uygulama açıkken paylaşılır"
            case .manual: return "Siz açıp kapattığınızda paylaşılır"
            }
        }
        
        var icon: String {
            switch self {
            case .always: return "location.fill"
            case .whenUsingApp: return "location"
            case .manual: return "hand.tap.fill"
            }
        }
        
        var requiresAlwaysAuthorization: Bool {
            return self == .always
        }
    }
    
    // MARK: - Computed Properties
    
    /// Yakınlık eşiği formatlanmış
    var formattedProximityThreshold: String {
        if proximityThreshold < 1000 {
            return "\(Int(proximityThreshold)) metre"
        } else {
            return String(format: "%.1f km", proximityThreshold / 1000)
        }
    }
    
    /// Minimum buluşma süresi formatlanmış
    var formattedMinimumMeetingDuration: String {
        if minimumMeetingDuration < 60 {
            return "\(Int(minimumMeetingDuration)) saniye"
        } else {
            return "\(Int(minimumMeetingDuration / 60)) dakika"
        }
    }
    
    // MARK: - Default Values
    
    static var `default`: LocationSharingSettings {
        LocationSharingSettings(
            isEnabled: false,
            updateFrequency: .normal,
            proximityThreshold: 100,        // 100 metre
            notificationsEnabled: true,
            sharingMode: .whenUsingApp,
            showBatteryLevel: true,
            showSpeed: false,
            showLastSeen: true,
            meetingDetectionEnabled: true,
            minimumMeetingDuration: 60      // 1 dakika
        )
    }
    
    // MARK: - Initializer
    
    init(
        isEnabled: Bool = false,
        updateFrequency: UpdateFrequency = .normal,
        proximityThreshold: Double = 100,
        notificationsEnabled: Bool = true,
        sharingMode: SharingMode = .whenUsingApp,
        showBatteryLevel: Bool = true,
        showSpeed: Bool = false,
        showLastSeen: Bool = true,
        meetingDetectionEnabled: Bool = true,
        minimumMeetingDuration: TimeInterval = 60
    ) {
        self.isEnabled = isEnabled
        self.updateFrequency = updateFrequency
        self.proximityThreshold = proximityThreshold
        self.notificationsEnabled = notificationsEnabled
        self.sharingMode = sharingMode
        self.showBatteryLevel = showBatteryLevel
        self.showSpeed = showSpeed
        self.showLastSeen = showLastSeen
        self.meetingDetectionEnabled = meetingDetectionEnabled
        self.minimumMeetingDuration = minimumMeetingDuration
    }
    
    // MARK: - Firebase Helpers
    
    /// Firestore'a yazılacak dictionary
    var firestoreData: [String: Any] {
        return [
            "isEnabled": isEnabled,
            "updateFrequency": updateFrequency.rawValue,
            "proximityThreshold": proximityThreshold,
            "notificationsEnabled": notificationsEnabled,
            "sharingMode": sharingMode.rawValue,
            "showBatteryLevel": showBatteryLevel,
            "showSpeed": showSpeed,
            "showLastSeen": showLastSeen,
            "meetingDetectionEnabled": meetingDetectionEnabled,
            "minimumMeetingDuration": minimumMeetingDuration
        ]
    }
    
    /// Firestore data'dan oluştur
    static func from(data: [String: Any]) -> LocationSharingSettings {
        return LocationSharingSettings(
            isEnabled: data["isEnabled"] as? Bool ?? false,
            updateFrequency: UpdateFrequency(rawValue: data["updateFrequency"] as? String ?? "normal") ?? .normal,
            proximityThreshold: data["proximityThreshold"] as? Double ?? 100,
            notificationsEnabled: data["notificationsEnabled"] as? Bool ?? true,
            sharingMode: SharingMode(rawValue: data["sharingMode"] as? String ?? "whenUsingApp") ?? .whenUsingApp,
            showBatteryLevel: data["showBatteryLevel"] as? Bool ?? true,
            showSpeed: data["showSpeed"] as? Bool ?? false,
            showLastSeen: data["showLastSeen"] as? Bool ?? true,
            meetingDetectionEnabled: data["meetingDetectionEnabled"] as? Bool ?? true,
            minimumMeetingDuration: data["minimumMeetingDuration"] as? TimeInterval ?? 60
        )
    }
    
    // MARK: - UserDefaults Storage
    
    private static let userDefaultsKey = "locationSharingSettings"
    
    /// UserDefaults'a kaydet
    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: Self.userDefaultsKey)
        }
    }
    
    /// UserDefaults'tan yükle
    static func load() -> LocationSharingSettings {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let settings = try? JSONDecoder().decode(LocationSharingSettings.self, from: data) else {
            return .default
        }
        return settings
    }
}

// MARK: - Proximity Threshold Presets
extension LocationSharingSettings {
    enum ProximityPreset: CaseIterable {
        case veryClose      // 25 metre
        case close          // 50 metre
        case normal         // 100 metre
        case far            // 250 metre
        case veryFar        // 500 metre
        
        var distance: Double {
            switch self {
            case .veryClose: return 25
            case .close: return 50
            case .normal: return 100
            case .far: return 250
            case .veryFar: return 500
            }
        }
        
        var displayName: String {
            switch self {
            case .veryClose: return "Çok Yakın (25m)"
            case .close: return "Yakın (50m)"
            case .normal: return "Normal (100m)"
            case .far: return "Uzak (250m)"
            case .veryFar: return "Çok Uzak (500m)"
            }
        }
        
        var description: String {
            switch self {
            case .veryClose: return "Yan yana olduğunuzda"
            case .close: return "Aynı mekandayken"
            case .normal: return "Yakın çevredeyken"
            case .far: return "Aynı sokaktayken"
            case .veryFar: return "Aynı bölgedeyken"
            }
        }
    }
}
