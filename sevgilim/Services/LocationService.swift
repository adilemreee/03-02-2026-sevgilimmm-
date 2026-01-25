//
//  LocationService.swift
//  sevgilim
//
//  Gelişmiş konum servisi - Partner konum takibi, buluşma algılama, arka plan güncellemeleri
//

import Foundation
import CoreLocation
import MapKit
import Combine
import FirebaseFirestore
import UIKit

class LocationService: NSObject, ObservableObject {
    // MARK: - Singleton
    static let shared = LocationService()
    
    // MARK: - Location Manager
    private let locationManager = CLLocationManager()
    private let db = Firestore.firestore()
    
    // MARK: - Published Properties - Temel
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocationEnabled = false
    @Published var locationError: String?
    
    // MARK: - Published Properties - Partner Konum
    @Published var partnerLocation: UserLocation?
    @Published var distanceToPartner: Double?
    @Published var bearingToPartner: Double?
    @Published var isNearPartner: Bool = false
    
    // MARK: - Published Properties - Paylaşım
    @Published var isSharingLocation: Bool = false
    @Published var userLocation: UserLocation?
    @Published var settings: LocationSharingSettings = .load()
    
    // MARK: - Published Properties - Buluşma
    @Published var currentMeeting: MeetingEvent?
    @Published var meetingDuration: TimeInterval = 0
    
    // MARK: - Computed Properties
    var isMeetingActive: Bool {
        currentMeeting?.isActive ?? false
    }
    
    // MARK: - Private Properties
    private var partnerLocationListener: ListenerRegistration?
    private var locationUpdateTimer: Timer?
    private var meetingTimer: Timer?
    private var currentUserId: String?
    private var currentRelationshipId: String?
    private var partnerId: String?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Callbacks
    var onProximityDetected: ((Double) -> Void)?
    var onMeetingStarted: ((MeetingEvent) -> Void)?
    var onMeetingEnded: ((MeetingEvent) -> Void)?
    var onPartnerLocationUpdated: ((UserLocation) -> Void)?
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupLocationManager()
        setupObservers()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // 10 metre değişimde güncelle
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.pausesLocationUpdatesAutomatically = true
        authorizationStatus = locationManager.authorizationStatus
    }
    
    private func setupObservers() {
        // Uygulama arka plana geçtiğinde
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleAppDidEnterBackground()
            }
            .store(in: &cancellables)
        
        // Uygulama ön plana geçtiğinde
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.handleAppWillEnterForeground()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Authorization
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }
    
    var hasAlwaysAuthorization: Bool {
        authorizationStatus == .authorizedAlways
    }
    
    var hasLocationAuthorization: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
    
    // MARK: - Location Fetching
    
    func getCurrentLocation() {
        guard hasLocationAuthorization else {
            locationError = "Konum izni verilmedi"
            return
        }
        
        guard CLLocationManager.locationServicesEnabled() else {
            locationError = "Konum servisleri kapalı"
            return
        }
        
        locationError = nil
        DispatchQueue.main.async {
            self.locationManager.requestLocation()
        }
    }
    
    // MARK: - Location Sharing
    
    /// Konum paylaşımını başlat
    func startSharingLocation(userId: String, relationshipId: String, partnerId: String) {
        self.currentUserId = userId
        self.currentRelationshipId = relationshipId
        self.partnerId = partnerId
        
        guard hasLocationAuthorization else {
            requestLocationPermission()
            return
        }
        
        isSharingLocation = true
        settings.isEnabled = true
        settings.save()
        
        // Konum güncellemelerini başlat
        startLocationUpdates()
        
        // Partner konumunu dinle
        listenToPartnerLocation(partnerId: partnerId)
        
        // Timer ile periyodik güncelleme
        startLocationUpdateTimer()
        
        print("📍 Konum paylaşımı başlatıldı")
    }
    
    /// Konum paylaşımını durdur
    func stopSharingLocation() {
        isSharingLocation = false
        settings.isEnabled = false
        settings.save()
        
        // Konum güncellemelerini durdur
        stopLocationUpdates()
        
        // Partner dinlemeyi durdur
        stopListeningToPartnerLocation()
        
        // Timer'ı durdur
        stopLocationUpdateTimer()
        
        // Firebase'de paylaşımı kapat
        if let userId = currentUserId {
            Task {
                try? await updateSharingStatus(userId: userId, isSharing: false)
            }
        }
        
        print("📍 Konum paylaşımı durduruldu")
    }
    
    // MARK: - Location Updates
    
    private func startLocationUpdates() {
        DispatchQueue.main.async {
            if self.settings.sharingMode == .always && self.hasAlwaysAuthorization {
                self.locationManager.allowsBackgroundLocationUpdates = true
                self.locationManager.startUpdatingLocation()
            } else {
                self.locationManager.startUpdatingLocation()
            }
        }
    }
    
    /// Konum servisini yapılandır
    func configure(userId: String, relationshipId: String) {
        self.currentUserId = userId
        self.currentRelationshipId = relationshipId
        
        // Kayıtlı ayarları yükle ve paylaşım durumunu geri yükle
        let savedSettings = LocationSharingSettings.load()
        self.settings = savedSettings
        self.isSharingLocation = savedSettings.isEnabled
        
        // Her zaman mevcut konumu al
        if hasLocationAuthorization {
            getCurrentLocation()
        }
        
        // Partner bilgisini al ve partner dinleyicisini başlat
        Task {
            await fetchPartnerIdAndStartListening(relationshipId: relationshipId, userId: userId)
            
            // Eğer paylaşım açıksa, konum güncellemelerini başlat
            if savedSettings.isEnabled {
                await MainActor.run {
                    if self.hasLocationAuthorization {
                        self.startLocationUpdates()
                        self.startLocationUpdateTimer()
                        print("📍 Konum paylaşımı otomatik başlatıldı")
                    }
                }
            }
        }
    }
    
    private func fetchPartnerIdAndStartListening(relationshipId: String, userId: String) async {
        do {
            let doc = try await db.collection("relationships").document(relationshipId).getDocument()
            if let data = doc.data() {
                let user1Id = data["user1Id"] as? String
                let user2Id = data["user2Id"] as? String
                self.partnerId = (userId == user1Id) ? user2Id : user1Id
                
                if let partnerId = self.partnerId {
                    listenToPartnerLocation(partnerId: partnerId)
                }
            }
        } catch {
            print("❌ Partner bilgisi alınamadı: \(error)")
        }
    }
    
    func stopLocationUpdates() {
        DispatchQueue.main.async {
            self.locationManager.stopUpdatingLocation()
            self.locationManager.allowsBackgroundLocationUpdates = false
        }
    }
    
    private func startLocationUpdateTimer() {
        stopLocationUpdateTimer()
        
        let interval = settings.updateFrequency.interval
        locationUpdateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.uploadCurrentLocation()
        }
    }
    
    private func stopLocationUpdateTimer() {
        locationUpdateTimer?.invalidate()
        locationUpdateTimer = nil
    }
    
    // MARK: - Firebase Operations
    
    /// Konumu Firebase'e yükle
    private func uploadCurrentLocation() {
        guard let location = currentLocation,
              let userId = currentUserId,
              isSharingLocation else { return }
        
        let batteryLevel = getBatteryLevel()
        
        var userLoc = UserLocation(
            userId: userId,
            location: location,
            isSharing: true,
            batteryLevel: batteryLevel
        )
        
        // Yer adını al ve kaydet
        getPlaceName(for: location) { [weak self] placeName, address in
            userLoc.placeName = placeName
            userLoc.address = address
            
            self?.userLocation = userLoc
            
            Task {
                try? await self?.saveLocationToFirebase(userLoc)
            }
        }
    }
    
    private func saveLocationToFirebase(_ location: UserLocation) async throws {
        try await db.collection("userLocations")
            .document(location.userId)
            .setData(location.firestoreData, merge: true)
    }
    
    private func updateSharingStatus(userId: String, isSharing: Bool) async throws {
        try await db.collection("userLocations")
            .document(userId)
            .updateData(["isSharing": isSharing, "lastUpdated": Timestamp(date: Date())])
    }
    
    // MARK: - Partner Location Listening
    
    func listenToPartnerLocation(partnerId: String) {
        stopListeningToPartnerLocation()
        
        self.partnerId = partnerId
        
        partnerLocationListener = db.collection("userLocations")
            .document(partnerId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Partner konum hatası: \(error.localizedDescription)")
                    return
                }
                
                guard let snapshot = snapshot,
                      let partnerLoc = UserLocation.from(document: snapshot) else {
                    self.partnerLocation = nil
                    return
                }
                
                DispatchQueue.main.async {
                    self.partnerLocation = partnerLoc
                    self.calculateDistanceToPartner()
                    self.checkProximity()
                    self.onPartnerLocationUpdated?(partnerLoc)
                }
            }
    }
    
    func stopListeningToPartnerLocation() {
        partnerLocationListener?.remove()
        partnerLocationListener = nil
        partnerLocation = nil
        distanceToPartner = nil
        isNearPartner = false
    }
    
    // MARK: - Distance & Proximity
    
    private func calculateDistanceToPartner() {
        guard let currentLocation = currentLocation,
              let partnerLocation = partnerLocation else {
            distanceToPartner = nil
            bearingToPartner = nil
            return
        }
        
        let partnerCLLocation = partnerLocation.clLocation
        distanceToPartner = currentLocation.distance(from: partnerCLLocation)
        bearingToPartner = calculateBearing(from: currentLocation, to: partnerCLLocation)
    }
    
    private func calculateBearing(from source: CLLocation, to destination: CLLocation) -> Double {
        let lat1 = source.coordinate.latitude * .pi / 180
        let lon1 = source.coordinate.longitude * .pi / 180
        let lat2 = destination.coordinate.latitude * .pi / 180
        let lon2 = destination.coordinate.longitude * .pi / 180
        
        let dLon = lon2 - lon1
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        
        var bearing = atan2(y, x) * 180 / .pi
        bearing = (bearing + 360).truncatingRemainder(dividingBy: 360)
        
        return bearing
    }
    
    private func checkProximity() {
        guard let distance = distanceToPartner else {
            isNearPartner = false
            return
        }
        
        let threshold = settings.proximityThreshold
        let wasNear = isNearPartner
        isNearPartner = distance <= threshold
        
        // Yakınlık durumu değişti
        if isNearPartner && !wasNear {
            // Yakınlaştılar - buluşma başlat
            onProximityDetected?(distance)
            
            if settings.meetingDetectionEnabled && currentMeeting == nil {
                startMeeting()
            }
        } else if !isNearPartner && wasNear {
            // Uzaklaştılar - buluşma bitir
            if currentMeeting != nil {
                endMeeting()
            }
        }
    }
    
    // MARK: - Meeting Management
    
    private func startMeeting() {
        guard let location = currentLocation,
              let relationshipId = currentRelationshipId,
              let userId = currentUserId,
              let partnerId = partnerId else { return }
        
        var meeting = MeetingEvent(
            relationshipId: relationshipId,
            user1Id: userId,
            user2Id: partnerId,
            location: location
        )
        
        // Yer adını al
        getPlaceName(for: location) { [weak self] placeName, address in
            meeting.placeName = placeName
            meeting.address = address
            
            self?.currentMeeting = meeting
            self?.meetingDuration = 0
            self?.startMeetingTimer()
            self?.onMeetingStarted?(meeting)
            
            // Firebase'e kaydet
            Task {
                try? await self?.saveMeetingToFirebase(meeting)
            }
            
            print("💕 Buluşma başladı: \(placeName ?? "Bilinmeyen konum")")
        }
    }
    
    private func endMeeting() {
        guard var meeting = currentMeeting else { return }
        
        meeting.end()
        
        // Minimum süreyi kontrol et
        if meeting.calculatedDuration >= settings.minimumMeetingDuration {
            onMeetingEnded?(meeting)
            
            // Firebase'de güncelle
            Task {
                try? await updateMeetingInFirebase(meeting)
            }
            
            print("💕 Buluşma bitti: \(meeting.formattedDuration)")
        } else {
            // Çok kısa, sil
            if let meetingId = meeting.id {
                Task {
                    try? await deleteMeetingFromFirebase(meetingId: meetingId)
                }
            }
            print("💕 Buluşma çok kısa, kaydedilmedi")
        }
        
        currentMeeting = nil
        meetingDuration = 0
        stopMeetingTimer()
    }
    
    private func startMeetingTimer() {
        stopMeetingTimer()
        
        meetingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self, let meeting = self.currentMeeting else { return }
            self.meetingDuration = Date().timeIntervalSince(meeting.startTime)
        }
    }
    
    private func stopMeetingTimer() {
        meetingTimer?.invalidate()
        meetingTimer = nil
    }
    
    // MARK: - Meeting Firebase Operations
    
    private func saveMeetingToFirebase(_ meeting: MeetingEvent) async throws {
        let docRef = try await db.collection("meetingEvents").addDocument(data: meeting.firestoreData)
        
        await MainActor.run {
            self.currentMeeting?.id = docRef.documentID
        }
    }
    
    private func updateMeetingInFirebase(_ meeting: MeetingEvent) async throws {
        guard let meetingId = meeting.id else { return }
        
        try await db.collection("meetingEvents")
            .document(meetingId)
            .updateData([
                "endTime": Timestamp(date: meeting.endTime ?? Date()),
                "duration": meeting.duration ?? 0,
                "isActive": false,
                "maxDistance": meeting.maxDistance,
                "minDistance": meeting.minDistance
            ])
    }
    
    private func deleteMeetingFromFirebase(meetingId: String) async throws {
        try await db.collection("meetingEvents").document(meetingId).delete()
    }
    
    /// Buluşma geçmişini getir
    func fetchMeetingHistory(relationshipId: String) async throws -> [MeetingEvent] {
        let snapshot = try await db.collection("meetingEvents")
            .whereField("relationshipId", isEqualTo: relationshipId)
            .whereField("isActive", isEqualTo: false)
            .order(by: "startTime", descending: true)
            .limit(to: 50)
            .getDocuments()
        
        return snapshot.documents.compactMap { MeetingEvent.from(document: $0) }
    }
    
    // MARK: - App Lifecycle
    
    private func handleAppDidEnterBackground() {
        if settings.sharingMode == .always && hasAlwaysAuthorization {
            locationManager.allowsBackgroundLocationUpdates = true
        } else if settings.sharingMode == .whenUsingApp {
            // Arka planda paylaşımı durdur ama listener'ı koru
            stopLocationUpdateTimer()
        }
    }
    
    private func handleAppWillEnterForeground() {
        if isSharingLocation {
            startLocationUpdateTimer()
            getCurrentLocation()
        }
    }
    
    // MARK: - Utility
    
    private func getBatteryLevel() -> Int {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        return Int(level * 100)
    }
    
    func getPlaceName(for location: CLLocation, completion: @escaping (String?, String?) -> Void) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print("❌ Geocoding error: \(error.localizedDescription)")
                completion(nil, nil)
                return
            }
            
            guard let placemark = placemarks?.first else {
                completion(nil, nil)
                return
            }
            
            var placeName = ""
            var address = ""
            
            // Yer adı için öncelik sırası
            if let name = placemark.name, !name.isEmpty {
                placeName = name
            } else if let thoroughfare = placemark.thoroughfare, !thoroughfare.isEmpty {
                placeName = thoroughfare
            } else if let locality = placemark.locality, !locality.isEmpty {
                placeName = locality
            } else {
                placeName = "Bilinmeyen Yer"
            }
            
            // Adres bilgisi oluştur
            var addressComponents: [String] = []
            
            if let thoroughfare = placemark.thoroughfare, !thoroughfare.isEmpty {
                addressComponents.append(thoroughfare)
            }
            
            if let subThoroughfare = placemark.subThoroughfare, !subThoroughfare.isEmpty {
                addressComponents.append(subThoroughfare)
            }
            
            if let locality = placemark.locality, !locality.isEmpty {
                addressComponents.append(locality)
            }
            
            if let administrativeArea = placemark.administrativeArea, !administrativeArea.isEmpty {
                addressComponents.append(administrativeArea)
            }
            
            if let country = placemark.country, !country.isEmpty {
                addressComponents.append(country)
            }
            
            address = addressComponents.joined(separator: ", ")
            
            completion(placeName, address.isEmpty ? nil : address)
        }
    }
    
    // MARK: - Formatted Distance
    
    var formattedDistanceToPartner: String {
        guard let distance = distanceToPartner else { return "Bilinmiyor" }
        
        if distance < 1000 {
            return "\(Int(distance))m"
        } else {
            return String(format: "%.1f km", distance / 1000)
        }
    }
    
    var detailedDistanceToPartner: String {
        guard let distance = distanceToPartner else { return "Mesafe bilinmiyor" }
        
        if distance < 1000 {
            return "\(Int(distance)) metre uzakta"
        } else {
            return String(format: "%.1f kilometre uzakta", distance / 1000)
        }
    }
    
    var directionToPartner: String {
        guard let bearing = bearingToPartner else { return "" }
        
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
    
    // MARK: - Settings
    
    func updateSettings(_ newSettings: LocationSharingSettings) {
        let wasEnabled = settings.isEnabled
        settings = newSettings
        settings.save()
        
        // Paylaşım durumu değiştiyse
        if newSettings.isEnabled && !wasEnabled {
            if let userId = currentUserId,
               let relationshipId = currentRelationshipId,
               let partnerId = partnerId {
                startSharingLocation(userId: userId, relationshipId: relationshipId, partnerId: partnerId)
            }
        } else if !newSettings.isEnabled && wasEnabled {
            stopSharingLocation()
        }
        
        // Güncelleme sıklığı değiştiyse timer'ı yeniden başlat
        if isSharingLocation {
            startLocationUpdateTimer()
        }
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        stopSharingLocation()
        cancellables.removeAll()
        currentUserId = nil
        currentRelationshipId = nil
        partnerId = nil
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Konum doğruluğunu kontrol et
        guard location.horizontalAccuracy >= 0 && location.horizontalAccuracy < 100 else {
            return
        }
        
        DispatchQueue.main.async {
            self.currentLocation = location
            self.isLocationEnabled = true
            self.locationError = nil
            
            // Mesafeyi güncelle
            self.calculateDistanceToPartner()
            
            // Yakınlık kontrolü
            self.checkProximity()
            
            // Aktif buluşma varsa mesafeyi güncelle
            if var meeting = self.currentMeeting,
               let distance = self.distanceToPartner {
                meeting.updateDistance(distance)
                self.currentMeeting = meeting
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            // Konum alınamama hatasını görmezden gel (geçici olabilir)
            if let clError = error as? CLError, clError.code == .locationUnknown {
                return
            }
            
            self.locationError = error.localizedDescription
            self.isLocationEnabled = false
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
            
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.isLocationEnabled = true
                self.locationError = nil
                
                // Always izni varsa background güncellemelerini etkinleştir
                if status == .authorizedAlways && self.settings.sharingMode == .always {
                    self.locationManager.allowsBackgroundLocationUpdates = true
                }
                
            case .denied, .restricted:
                self.isLocationEnabled = false
                self.locationError = "Konum izni reddedildi"
                self.stopSharingLocation()
                
            case .notDetermined:
                self.isLocationEnabled = false
                self.locationError = nil
                
            @unknown default:
                self.isLocationEnabled = false
                self.locationError = "Bilinmeyen konum izni durumu"
            }
        }
    }
}
