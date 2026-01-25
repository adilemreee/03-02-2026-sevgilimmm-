//
//  LocationViewModel.swift
//  sevgilim
//
//  Konum özelliği için ViewModel - Harita, partner konum, buluşma yönetimi
//

import Foundation
import CoreLocation
import MapKit
import Combine
import SwiftUI

@MainActor
class LocationViewModel: ObservableObject {
    // MARK: - Services
    private let locationService: LocationService
    private let meetingService: MeetingService
    
    // MARK: - Published - Konum
    @Published var userLocation: UserLocation?
    @Published var partnerLocation: UserLocation?
    @Published var distanceToPartner: Double?
    @Published var bearingToPartner: Double?
    @Published var isNearPartner: Bool = false
    
    // MARK: - Published - Harita
    @Published var mapRegion: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784), // İstanbul
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @Published var mapCameraPosition: MapCameraPosition = .automatic
    @Published var showBothUsers: Bool = true
    @Published var selectedMapStyle: MapStyle = .standard
    
    enum MapStyle: String, CaseIterable {
        case standard = "Standart"
        case satellite = "Uydu"
        case hybrid = "Hibrit"
    }
    
    // MARK: - Published - Buluşma
    @Published var isInMeeting: Bool = false
    @Published var currentMeeting: MeetingEvent?
    @Published var meetingDuration: TimeInterval = 0
    @Published var meetingHistory: [MeetingEvent] = []
    
    // MARK: - Published - Paylaşım
    @Published var isSharingLocation: Bool = false
    @Published var settings: LocationSharingSettings = .load()
    @Published var hasLocationPermission: Bool = false
    @Published var hasAlwaysPermission: Bool = false
    
    // MARK: - Published - UI State
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showMeetingBanner: Bool = false
    @Published var showSettings: Bool = false
    @Published var showHistory: Bool = false
    
    // MARK: - User Info
    private var currentUserId: String?
    private var currentRelationshipId: String?
    private var partnerId: String?
    private var partnerName: String?
    
    // MARK: - Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(locationService: LocationService = .shared, meetingService: MeetingService = .shared) {
        self.locationService = locationService
        self.meetingService = meetingService
        
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Location Service bindings
        locationService.$currentLocation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                guard let self = self, let location = location, let userId = self.currentUserId else { return }
                self.userLocation = UserLocation(userId: userId, location: location, isSharing: self.isSharingLocation)
            }
            .store(in: &cancellables)
        
        locationService.$partnerLocation
            .receive(on: DispatchQueue.main)
            .assign(to: &$partnerLocation)
        
        locationService.$distanceToPartner
            .receive(on: DispatchQueue.main)
            .assign(to: &$distanceToPartner)
        
        locationService.$bearingToPartner
            .receive(on: DispatchQueue.main)
            .assign(to: &$bearingToPartner)
        
        locationService.$isNearPartner
            .receive(on: DispatchQueue.main)
            .assign(to: &$isNearPartner)
        
        locationService.$isSharingLocation
            .receive(on: DispatchQueue.main)
            .assign(to: &$isSharingLocation)
        
        locationService.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.hasLocationPermission = status == .authorizedWhenInUse || status == .authorizedAlways
                self?.hasAlwaysPermission = status == .authorizedAlways
            }
            .store(in: &cancellables)
        
        // Meeting Service bindings
        meetingService.$currentMeeting
            .receive(on: DispatchQueue.main)
            .sink { [weak self] meeting in
                self?.currentMeeting = meeting
                self?.isInMeeting = meeting != nil
                self?.showMeetingBanner = meeting != nil
            }
            .store(in: &cancellables)
        
        meetingService.$meetingDuration
            .receive(on: DispatchQueue.main)
            .assign(to: &$meetingDuration)
        
        meetingService.$meetingHistory
            .receive(on: DispatchQueue.main)
            .assign(to: &$meetingHistory)
        
        meetingService.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)
        
        meetingService.$errorMessage
            .receive(on: DispatchQueue.main)
            .assign(to: &$errorMessage)
    }
    
    // MARK: - Configuration
    
    func configure(userId: String, relationshipId: String, partnerId: String, partnerName: String) {
        self.currentUserId = userId
        self.currentRelationshipId = relationshipId
        self.partnerId = partnerId
        self.partnerName = partnerName
        
        // Kayıtlı ayarlardan paylaşım durumunu yükle
        let savedSettings = LocationSharingSettings.load()
        self.settings = savedSettings
        self.isSharingLocation = savedSettings.isEnabled
        
        // Eğer paylaşım açıksa otomatik başlat
        if savedSettings.isEnabled && hasLocationPermission {
            locationService.startSharingLocation(userId: userId, relationshipId: relationshipId, partnerId: partnerId)
        }
        
        // Kullanıcı konumuna odaklan
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.centerOnUserIfAvailable()
        }
        
        // Aktif buluşma kontrolü
        Task {
            await meetingService.checkForActiveMeeting(relationshipId: relationshipId, userId: userId)
        }
        
        // Buluşma geçmişini yükle
        Task {
            await meetingService.loadMeetingHistory(relationshipId: relationshipId)
        }
    }
    
    /// Kullanıcı konumu varsa oraya odaklan
    private func centerOnUserIfAvailable() {
        if let location = locationService.currentLocation {
            withAnimation {
                mapRegion = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            }
        } else if let userLoc = userLocation {
            withAnimation {
                mapRegion = MKCoordinateRegion(
                    center: userLoc.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            }
        }
    }
    
    // MARK: - Location Sharing
    
    func startLocationSharing() {
        guard let userId = currentUserId,
              let relationshipId = currentRelationshipId,
              let partnerId = partnerId else {
            errorMessage = "Kullanıcı bilgileri eksik"
            return
        }
        
        if !hasLocationPermission {
            locationService.requestLocationPermission()
            return
        }
        
        locationService.startSharingLocation(userId: userId, relationshipId: relationshipId, partnerId: partnerId)
        settings.isEnabled = true
        settings.save()
    }
    
    func stopLocationSharing() {
        locationService.stopSharingLocation()
        settings.isEnabled = false
        settings.save()
    }
    
    func toggleLocationSharing() {
        if isSharingLocation {
            stopLocationSharing()
        } else {
            startLocationSharing()
        }
    }
    
    // MARK: - Permissions
    
    func requestLocationPermission() {
        locationService.requestLocationPermission()
    }
    
    func requestAlwaysPermission() {
        locationService.requestAlwaysAuthorization()
    }
    
    // MARK: - Map Controls
    
    func centerOnUser() {
        guard let location = userLocation else { return }
        
        withAnimation {
            mapRegion = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
    }
    
    func centerOnPartner() {
        guard let location = partnerLocation else { return }
        
        withAnimation {
            mapRegion = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
    }
    
    func showBothLocations() {
        guard let userLoc = userLocation,
              let partnerLoc = partnerLocation else {
            // Sadece birinin konumu varsa onu göster
            if let userLoc = userLocation {
                centerOnUser()
            } else if let partnerLoc = partnerLocation {
                centerOnPartner()
            }
            return
        }
        
        // Her iki konumu da kapsayan region hesapla
        let minLat = min(userLoc.latitude, partnerLoc.latitude)
        let maxLat = max(userLoc.latitude, partnerLoc.latitude)
        let minLon = min(userLoc.longitude, partnerLoc.longitude)
        let maxLon = max(userLoc.longitude, partnerLoc.longitude)
        
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        
        let latDelta = (maxLat - minLat) * 1.5 + 0.01
        let lonDelta = (maxLon - minLon) * 1.5 + 0.01
        
        withAnimation {
            mapRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                span: MKCoordinateSpan(latitudeDelta: max(latDelta, 0.01), longitudeDelta: max(lonDelta, 0.01))
            )
        }
    }
    
    func refreshLocation() {
        locationService.getCurrentLocation()
    }
    
    // MARK: - Settings
    
    func updateSettings(_ newSettings: LocationSharingSettings) {
        settings = newSettings
        locationService.updateSettings(newSettings)
    }
    
    // MARK: - Meeting
    
    func endMeetingManually() async {
        await meetingService.endMeetingManually()
        showMeetingBanner = false
    }
    
    func dismissMeetingBanner() {
        showMeetingBanner = false
    }
    
    func loadMeetingHistory() async {
        guard let relationshipId = currentRelationshipId else { return }
        await meetingService.loadMeetingHistory(relationshipId: relationshipId)
    }
    
    func deleteMeeting(_ meeting: MeetingEvent) async {
        await meetingService.deleteMeeting(meeting)
    }
    
    // MARK: - Formatted Properties
    
    var formattedDistance: String {
        locationService.formattedDistanceToPartner
    }
    
    var detailedDistance: String {
        locationService.detailedDistanceToPartner
    }
    
    var directionToPartner: String {
        locationService.directionToPartner
    }
    
    var formattedMeetingDuration: String {
        meetingService.formattedMeetingDuration
    }
    
    var partnerLastSeen: String {
        partnerLocation?.lastUpdatedAgo ?? "Bilinmiyor"
    }
    
    var partnerPlaceName: String {
        partnerLocation?.placeName ?? partnerLocation?.address ?? "Konum bilinmiyor"
    }
    
    var isPartnerLocationRecent: Bool {
        partnerLocation?.isRecent ?? false
    }
    
    var partnerBatteryLevel: Int? {
        guard settings.showBatteryLevel else { return nil }
        return partnerLocation?.batteryLevel
    }
    
    var partnerSpeed: String? {
        guard settings.showSpeed else { return nil }
        return partnerLocation?.formattedSpeed
    }
    
    // MARK: - Statistics
    
    var totalMeetings: Int {
        meetingService.totalMeetings
    }
    
    var totalMeetingTime: String {
        meetingService.formattedTotalMeetingTime
    }
    
    var averageMeetingDuration: String {
        meetingService.formattedAverageDuration
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        locationService.cleanup()
        meetingService.cleanup()
        cancellables.removeAll()
    }
}

// MARK: - Map Annotations
extension LocationViewModel {
    var userAnnotation: LocationAnnotation? {
        guard let location = userLocation else { return nil }
        return LocationAnnotation(
            id: "user",
            coordinate: location.coordinate,
            title: "Sen",
            type: .user
        )
    }
    
    var partnerAnnotation: LocationAnnotation? {
        guard let location = partnerLocation else { return nil }
        return LocationAnnotation(
            id: "partner",
            coordinate: location.coordinate,
            title: partnerName ?? "Sevgilin",
            type: .partner,
            lastUpdated: location.lastUpdated,
            batteryLevel: location.batteryLevel
        )
    }
    
    var allAnnotations: [LocationAnnotation] {
        [userAnnotation, partnerAnnotation].compactMap { $0 }
    }
}

// MARK: - Location Annotation Model
struct LocationAnnotation: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let title: String
    let type: AnnotationType
    var lastUpdated: Date?
    var batteryLevel: Int?
    
    enum AnnotationType {
        case user
        case partner
        case meeting
    }
}
