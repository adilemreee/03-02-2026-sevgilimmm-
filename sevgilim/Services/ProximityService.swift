//
//  ProximityService.swift
//  sevgilim
//
//  Proximity notification service - notifies when partners are nearby
//

import Foundation
import CoreLocation
import Combine
import FirebaseFirestore
import UserNotifications
import UIKit

@MainActor
class ProximityService: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    // MARK: - Published Properties
    @Published var partnerLocation: CLLocation?
    @Published var userLocation: CLLocation?
    @Published var distanceToPartner: Double?
    @Published var isNearby: Bool = false
    @Published var isTrackingEnabled: Bool = false
    @Published var lastNotificationTime: Date?
    @Published var lastPartnerUpdateTime: Date?
    
    // MARK: - Settings (UserDefaults backed)
    @Published var proximityThreshold: Double {
        didSet {
            UserDefaults.standard.set(proximityThreshold, forKey: "proximityThreshold")
            if isTrackingEnabled {
                reconfigureLocationMonitoring()
            }
            checkProximity() // Threshold değişince yeniden hesapla
        }
    }
    
    @Published var proximityNotificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(proximityNotificationsEnabled, forKey: "proximityNotificationsEnabled")
        }
    }
    
    // MARK: - Private Properties
    private let db = Firestore.firestore()
    private var locationListener: ListenerRegistration?
    private var locationManager: CLLocationManager?
    private var cancellables = Set<AnyCancellable>()
    private var currentUserId: String?
    private var lastUploadedLocation: CLLocation?
    private var lastLocationUploadTime: Date?
    private var isUploadingLocation = false
    
    // Cooldown: 10 dakika
    private let notificationCooldown: TimeInterval = 10 * 60
    private let minimumUploadInterval: TimeInterval = 5 * 60
    private let minimumUploadDistance: CLLocationDistance = 250
    private let minimumMeaningfulMovement: CLLocationDistance = 75
    private let foregroundMinimumDistance: CLLocationDistance = 150
    private let backgroundMinimumDistance: CLLocationDistance = 500
    private let maximumAcceptedAccuracy: CLLocationAccuracy = 400
    
    // MARK: - Threshold Options
    static let thresholdOptions: [(label: String, value: Double)] = [
        ("100 metre", 100),
        ("250 metre", 250),
        ("500 metre", 500),
        ("1 kilometre", 1000)
    ]
    
    // MARK: - Init
    override init() {
        let savedThreshold = UserDefaults.standard.double(forKey: "proximityThreshold")
        self.proximityThreshold = savedThreshold == 0 ? 500 : savedThreshold
        
        self.proximityNotificationsEnabled = UserDefaults.standard.bool(forKey: "proximityNotificationsEnabled")
        
        super.init()
        setupLocationManager()
        setupLifecycleObservers()
    }
    
    // MARK: - Location Manager Setup
    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager?.allowsBackgroundLocationUpdates = true
        locationManager?.pausesLocationUpdatesAutomatically = true
        locationManager?.distanceFilter = foregroundMinimumDistance
    }
    
    private func setupLifecycleObservers() {
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                guard let self, self.isTrackingEnabled else { return }
                self.reconfigureLocationMonitoring()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                guard let self, self.isTrackingEnabled else { return }
                self.reconfigureLocationMonitoring()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - CLLocationManagerDelegate
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { @MainActor in
            guard self.shouldAccept(location: location) else { return }
            
            if let previousLocation = self.userLocation,
               location.distance(from: previousLocation) < self.minimumMeaningfulMovement {
                return
            }
            
            self.userLocation = location
            self.checkProximity()
            
            // Firebase'e konum güncelle
            if let userId = self.currentUserId {
                self.updateUserLocationToFirebaseIfNeeded(
                    userId: userId,
                    location: location
                )
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location manager error: \(error.localizedDescription)")
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            if status == .authorizedAlways || status == .authorizedWhenInUse {
                self.reconfigureLocationMonitoring()
            }
        }
    }
    
    // MARK: - Start/Stop Tracking
    func startTracking(userId: String, partnerId: String, relationshipId: String) {
        // User ID'yi güncelle
        self.currentUserId = userId
        
        if isTrackingEnabled {
            // Zaten tracking açıksa, modları yeniden ayarla ve hafif refresh yap
            reconfigureLocationMonitoring()
            forceRefresh(forceUpload: false)
            print("🔄 Proximity tracking refreshed")
            return
        }
        
        isTrackingEnabled = true
        
        // Partner konumunu dinle
        startListeningToPartnerLocation(partnerId: partnerId)
        
        // Konum güncellemelerini başlat
        reconfigureLocationMonitoring()
        
        print("✅ Proximity tracking started for user: \(userId), partner: \(partnerId)")
    }
    
    func stopTracking() {
        isTrackingEnabled = false
        locationListener?.remove()
        locationListener = nil
        locationManager?.stopUpdatingLocation()
        locationManager?.stopMonitoringSignificantLocationChanges()
        currentUserId = nil
        distanceToPartner = nil
        partnerLocation = nil
        userLocation = nil
        lastUploadedLocation = nil
        lastLocationUploadTime = nil
        isUploadingLocation = false
        
        print("🔴 Proximity tracking stopped")
    }
    
    // MARK: - Start Location Updates
    private func reconfigureLocationMonitoring() {
        guard let locationManager = locationManager else { return }
        
        // Always authorization iste
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse {
            locationManager.requestAlwaysAuthorization()
        }
        
        guard status == .authorizedAlways || status == .authorizedWhenInUse else {
            return
        }
        
        let isForeground = UIApplication.shared.applicationState == .active
        
        if isForeground {
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            locationManager.distanceFilter = max(
                foregroundMinimumDistance,
                proximityThreshold / 2
            )
            locationManager.stopMonitoringSignificantLocationChanges()
            locationManager.startUpdatingLocation()
        } else {
            locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
            locationManager.distanceFilter = max(
                backgroundMinimumDistance,
                proximityThreshold
            )
            locationManager.stopUpdatingLocation()
            locationManager.startMonitoringSignificantLocationChanges()
        }
        
        // İlk konum varsa hemen kullan
        if let location = locationManager.location,
           shouldAccept(location: location) {
            self.userLocation = location
            checkProximity()
            
            if let userId = currentUserId {
                updateUserLocationToFirebaseIfNeeded(
                    userId: userId,
                    location: location
                )
            }
        }
    }
    
    // MARK: - Partner Location Listener
    private func startListeningToPartnerLocation(partnerId: String) {
        locationListener?.remove()
        
        locationListener = db.collection("userLocations")
            .document(partnerId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Partner location error: \(error.localizedDescription)")
                    return
                }
                
                guard let data = snapshot?.data(),
                      let latitude = data["latitude"] as? Double,
                      let longitude = data["longitude"] as? Double else {
                    return
                }
                // Extract timestamp from Firebase
                let timestamp: Date?
                if let ts = data["timestamp"] as? Timestamp {
                    timestamp = ts.dateValue()
                } else {
                    timestamp = nil
                }
                
                
                
                Task { @MainActor in
                    self.partnerLocation = CLLocation(latitude: latitude, longitude: longitude)
                    self.lastPartnerUpdateTime = timestamp
                    self.checkProximity()
                }
            }
    }
    
    // MARK: - Update User Location to Firebase
    private func updateUserLocationToFirebaseIfNeeded(
        userId: String,
        location: CLLocation,
        force: Bool = false
    ) {
        guard !isUploadingLocation else { return }
        guard shouldUpload(location: location, force: force) else { return }
        
        isUploadingLocation = true
        updateUserLocationToFirebase(userId: userId, location: location)
    }
    
    private func updateUserLocationToFirebase(userId: String, location: CLLocation) {
        let locationData: [String: Any] = [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "timestamp": Timestamp(date: Date()),
            "accuracy": location.horizontalAccuracy
        ]
        
        db.collection("userLocations")
            .document(userId)
            .setData(locationData, merge: true) { error in
                Task { @MainActor in
                    self.isUploadingLocation = false
                }
                
                if let error = error {
                    print("❌ Location update error: \(error.localizedDescription)")
                } else {
                    Task { @MainActor in
                        self.lastUploadedLocation = location
                        self.lastLocationUploadTime = Date()
                    }
                    print("📍 Location updated")
                }
            }
    }
    
    // MARK: - Force Refresh (can be called from outside)
    func forceRefresh(forceUpload: Bool = true) {
        // Mevcut konumu al ve hesapla
        if let location = locationManager?.location {
            self.userLocation = location
        }
        checkProximity()
        
        // Firebase'e konumu güncelle
        if let userId = currentUserId, let location = userLocation {
            updateUserLocationToFirebaseIfNeeded(
                userId: userId,
                location: location,
                force: forceUpload
            )
        }
    }
    
    private func shouldAccept(location: CLLocation) -> Bool {
        guard location.horizontalAccuracy >= 0 else { return false }
        
        if location.horizontalAccuracy <= maximumAcceptedAccuracy {
            return true
        }
        
        // İlk konum daha kaba da olsa kabul edilsin
        return userLocation == nil
    }
    
    private func shouldUpload(location: CLLocation, force: Bool) -> Bool {
        if force {
            return true
        }
        
        guard location.horizontalAccuracy >= 0 else { return false }
        
        if let lastLocationUploadTime,
           Date().timeIntervalSince(lastLocationUploadTime) >= minimumUploadInterval {
            return true
        }
        
        guard let lastUploadedLocation else {
            return true
        }
        
        return location.distance(from: lastUploadedLocation) >= minimumUploadDistance
    }
    
    // MARK: - Check Proximity
    private func checkProximity() {
        // userLocation property'sini veya locationManager'ın konumunu kullan
        let currentUserLocation = userLocation ?? locationManager?.location
        
        guard let userLoc = currentUserLocation,
              let partnerLoc = partnerLocation else {
            distanceToPartner = nil
            isNearby = false
            return
        }
        
        let distance = userLoc.distance(from: partnerLoc)
        distanceToPartner = distance
        
        let wasNearby = isNearby
        isNearby = distance <= proximityThreshold
        
        print("📍 Distance calculated: \(Int(distance))m (threshold: \(Int(proximityThreshold))m)")
        
        // Yeni yakınlaşma olduysa bildirim gönder
        if isNearby && !wasNearby && proximityNotificationsEnabled {
            sendProximityNotification(distance: distance)
        }
    }
    
    // MARK: - Send Notification
    private func sendProximityNotification(distance: Double) {
        // Cooldown kontrolü
        if let lastTime = lastNotificationTime,
           Date().timeIntervalSince(lastTime) < notificationCooldown {
            print("⏳ Notification cooldown active")
            return
        }
        
        lastNotificationTime = Date()
        
        let content = UNMutableNotificationContent()
        content.title = "💕 Yakınındasınız!"
        content.body = formatDistanceMessage(distance)
        content.sound = .default
        content.categoryIdentifier = "PROXIMITY"
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Hemen gönder
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Notification error: \(error.localizedDescription)")
            } else {
                print("💕 Proximity notification sent!")
            }
        }
    }
    
    private func formatDistanceMessage(_ distance: Double) -> String {
        if distance < 100 {
            return "Aşkının kollarındasın... 💑"
        } else if distance < 500 {
            return "Aşkın yaklaşık \(Int(distance)) metre uzaklıkta"
        } else {
            let km = distance / 1000
            return String(format: "Aşkın yaklaşık %.1f km uzaklıkta", km)
        }
    }
    
    // MARK: - Distance Formatted
    var distanceFormatted: String? {
        guard let distance = distanceToPartner else { return nil }
        
        if distance < 1000 {
            return "\(Int(distance)) m"
        } else {
            let km = distance / 1000
            return String(format: "%.1f km", km)
        }
    }
    
    // MARK: - Cleanup
    func cleanup() {
        stopTracking()
        cancellables.removeAll()
    }
    
    deinit {
        locationListener?.remove()
    }
}
