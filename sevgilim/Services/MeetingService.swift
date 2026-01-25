//
//  MeetingService.swift
//  sevgilim
//
//  Buluşma yönetimi servisi - Buluşma algılama, bildirim gönderme, geçmiş yönetimi
//

import Foundation
import Combine
import FirebaseFirestore
import CoreLocation
import UserNotifications

@MainActor
class MeetingService: ObservableObject {
    // MARK: - Singleton
    static let shared = MeetingService()
    
    // MARK: - Published Properties
    @Published var currentMeeting: MeetingEvent?
    @Published var meetingHistory: [MeetingEvent] = []
    @Published var isInMeeting: Bool = false
    @Published var meetingDuration: TimeInterval = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Statistics
    @Published var totalMeetings: Int = 0
    @Published var totalMeetingTime: TimeInterval = 0
    @Published var averageMeetingDuration: TimeInterval = 0
    @Published var longestMeeting: MeetingEvent?
    
    // MARK: - Private Properties
    private let db = Firestore.firestore()
    private var meetingListener: ListenerRegistration?
    private var meetingTimer: Timer?
    private var proximityStartTime: Date?
    private var lastNotificationTime: Date?
    
    // Minimum süre bildirimi göndermeden önce (saniye)
    private let notificationCooldown: TimeInterval = 3600 // 1 saat
    
    // MARK: - Configuration
    private var relationshipId: String?
    
    // MARK: - Initialization
    
    init() {}
    
    /// Meeting servisini yapılandır
    func configure(relationshipId: String) {
        self.relationshipId = relationshipId
        
        // Buluşma geçmişini yükle
        Task {
            await loadMeetingHistory(relationshipId: relationshipId)
        }
    }
    
    // MARK: - Meeting Detection
    
    /// Yakınlık algılandığında çağrılır
    func onProximityDetected(
        relationshipId: String,
        userId: String,
        partnerId: String,
        location: CLLocation,
        distance: Double,
        settings: LocationSharingSettings
    ) async {
        // Zaten buluşmadaysak yeni buluşma başlatma
        guard currentMeeting == nil else {
            // Mevcut buluşmadaki mesafeyi güncelle
            if var meeting = currentMeeting {
                meeting.updateDistance(distance)
                currentMeeting = meeting
            }
            return
        }
        
        // Minimum süre kontrolü
        if proximityStartTime == nil {
            proximityStartTime = Date()
        }
        
        let proximityDuration = Date().timeIntervalSince(proximityStartTime!)
        
        // Minimum yakınlık süresi geçti mi? (bildirim spam önleme)
        guard proximityDuration >= settings.minimumMeetingDuration else {
            return
        }
        
        // Buluşmayı başlat
        await startMeeting(
            relationshipId: relationshipId,
            userId: userId,
            partnerId: partnerId,
            location: location,
            distance: distance,
            sendNotification: settings.notificationsEnabled
        )
    }
    
    /// Yakınlık sona erdiğinde çağrılır
    func onProximityEnded() async {
        proximityStartTime = nil
        
        guard currentMeeting != nil else { return }
        
        await endCurrentMeeting()
    }
    
    // MARK: - Meeting Management
    
    /// Yeni buluşma başlat
    func startMeeting(
        relationshipId: String,
        userId: String,
        partnerId: String,
        location: CLLocation,
        distance: Double,
        sendNotification: Bool = true
    ) async {
        var meeting = MeetingEvent(
            relationshipId: relationshipId,
            user1Id: userId,
            user2Id: partnerId,
            location: location
        )
        meeting.minDistance = distance
        meeting.maxDistance = distance
        
        // Yer adını al
        await withCheckedContinuation { continuation in
            LocationService.shared.getPlaceName(for: location) { placeName, address in
                meeting.placeName = placeName
                meeting.address = address
                continuation.resume()
            }
        }
        
        do {
            // Firebase'e kaydet
            let docRef = try await db.collection("meetingEvents").addDocument(data: meeting.firestoreData)
            meeting.id = docRef.documentID
            
            currentMeeting = meeting
            isInMeeting = true
            meetingDuration = 0
            
            // Timer başlat
            startMeetingTimer()
            
            // Bildirim gönder
            if sendNotification {
                await sendMeetingNotification(meeting: meeting, partnerId: partnerId)
            }
            
            print("💕 Buluşma başladı: \(meeting.placeName ?? "Konum")")
            
        } catch {
            print("❌ Buluşma başlatma hatası: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
    
    /// Mevcut buluşmayı bitir
    func endCurrentMeeting() async {
        guard var meeting = currentMeeting else { return }
        
        meeting.end()
        
        // Firebase'de güncelle
        if let meetingId = meeting.id {
            do {
                try await db.collection("meetingEvents")
                    .document(meetingId)
                    .updateData([
                        "endTime": Timestamp(date: meeting.endTime ?? Date()),
                        "duration": meeting.calculatedDuration,
                        "isActive": false,
                        "maxDistance": meeting.maxDistance,
                        "minDistance": meeting.minDistance
                    ])
                
                // İstatistikleri güncelle
                await updateStatistics(with: meeting)
                
                print("💕 Buluşma bitti: \(meeting.formattedDuration)")
                
            } catch {
                print("❌ Buluşma bitirme hatası: \(error.localizedDescription)")
            }
        }
        
        currentMeeting = nil
        isInMeeting = false
        meetingDuration = 0
        stopMeetingTimer()
    }
    
    /// Buluşmayı manuel olarak bitir
    func endMeetingManually() async {
        await endCurrentMeeting()
    }
    
    // MARK: - Meeting Timer
    
    private func startMeetingTimer() {
        stopMeetingTimer()
        
        meetingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let meeting = self.currentMeeting else { return }
                self.meetingDuration = Date().timeIntervalSince(meeting.startTime)
            }
        }
    }
    
    private func stopMeetingTimer() {
        meetingTimer?.invalidate()
        meetingTimer = nil
    }
    
    // MARK: - Meeting History
    
    /// Buluşma geçmişini yükle
    func loadMeetingHistory(relationshipId: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let snapshot = try await db.collection("meetingEvents")
                .whereField("relationshipId", isEqualTo: relationshipId)
                .order(by: "startTime", descending: true)
                .limit(to: 100)
                .getDocuments()
            
            meetingHistory = snapshot.documents.compactMap { MeetingEvent.from(document: $0) }
            
            // İstatistikleri hesapla
            calculateStatistics()
            
            isLoading = false
            
        } catch {
            print("❌ Buluşma geçmişi yükleme hatası: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    /// Aktif buluşmayı kontrol et
    func checkForActiveMeeting(relationshipId: String, userId: String) async {
        do {
            let snapshot = try await db.collection("meetingEvents")
                .whereField("relationshipId", isEqualTo: relationshipId)
                .whereField("isActive", isEqualTo: true)
                .limit(to: 1)
                .getDocuments()
            
            if let doc = snapshot.documents.first,
               let meeting = MeetingEvent.from(document: doc) {
                // Kullanıcı bu buluşmanın parçası mı?
                if meeting.user1Id == userId || meeting.user2Id == userId {
                    currentMeeting = meeting
                    isInMeeting = true
                    meetingDuration = Date().timeIntervalSince(meeting.startTime)
                    startMeetingTimer()
                }
            }
            
        } catch {
            print("❌ Aktif buluşma kontrolü hatası: \(error.localizedDescription)")
        }
    }
    
    /// Buluşma geçmişini dinle (real-time)
    func listenToMeetingHistory(relationshipId: String) {
        meetingListener?.remove()
        
        meetingListener = db.collection("meetingEvents")
            .whereField("relationshipId", isEqualTo: relationshipId)
            .order(by: "startTime", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Buluşma dinleme hatası: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                Task { @MainActor in
                    self.meetingHistory = documents.compactMap { MeetingEvent.from(document: $0) }
                    self.calculateStatistics()
                }
            }
    }
    
    func stopListeningToMeetingHistory() {
        meetingListener?.remove()
        meetingListener = nil
    }
    
    // MARK: - Statistics
    
    private func calculateStatistics() {
        let completedMeetings = meetingHistory.filter { !$0.isActive }
        
        totalMeetings = completedMeetings.count
        totalMeetingTime = completedMeetings.reduce(0) { $0 + $1.calculatedDuration }
        
        if totalMeetings > 0 {
            averageMeetingDuration = totalMeetingTime / Double(totalMeetings)
        }
        
        longestMeeting = completedMeetings.max(by: { $0.calculatedDuration < $1.calculatedDuration })
    }
    
    private func updateStatistics(with meeting: MeetingEvent) async {
        // Relationship'teki istatistikleri güncelle
        do {
            try await db.collection("relationships")
                .document(meeting.relationshipId)
                .updateData([
                    "totalMeetingCount": FieldValue.increment(Int64(1)),
                    "totalMeetingDuration": FieldValue.increment(meeting.calculatedDuration),
                    "lastMeetingDate": Timestamp(date: meeting.startTime),
                    "lastMeetingLocation": GeoPoint(latitude: meeting.latitude, longitude: meeting.longitude)
                ])
        } catch {
            print("❌ İstatistik güncelleme hatası: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Notifications
    
    private func sendMeetingNotification(meeting: MeetingEvent, partnerId: String) async {
        // Bildirim cooldown kontrolü
        if let lastTime = lastNotificationTime,
           Date().timeIntervalSince(lastTime) < notificationCooldown {
            return
        }
        
        lastNotificationTime = Date()
        
        // Yerel bildirim gönder
        await sendLocalNotification(meeting: meeting)
        
        // Push bildirim gönder (partner'a)
        await sendPushNotification(to: partnerId, meeting: meeting)
    }
    
    private func sendLocalNotification(meeting: MeetingEvent) async {
        let content = UNMutableNotificationContent()
        content.title = "Buluştunuz! 💕"
        content.body = meeting.placeName != nil 
            ? "Sevgilinle \(meeting.placeName!) konumunda buluştunuz!"
            : "Sevgilinle buluştunuz!"
        content.sound = .default
        content.categoryIdentifier = "MEETING_NOTIFICATION"
        
        // Hemen göster
        let request = UNNotificationRequest(
            identifier: "meeting_\(meeting.id ?? UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("❌ Yerel bildirim hatası: \(error.localizedDescription)")
        }
    }
    
    private func sendPushNotification(to userId: String, meeting: MeetingEvent) async {
        // FCM token'ı al ve bildirim gönder
        do {
            let userDoc = try await db.collection("users").document(userId).getDocument()
            
            guard let tokens = userDoc.data()?["fcmTokens"] as? [String], !tokens.isEmpty else {
                return
            }
            
            // Cloud Function çağır veya doğrudan FCM'e gönder
            // Bu genellikle Cloud Function ile yapılır
            let notificationData: [String: Any] = [
                "tokens": tokens,
                "title": "Buluştunuz! 💕",
                "body": meeting.placeName != nil 
                    ? "Sevgilinle \(meeting.placeName!) konumunda buluştunuz!"
                    : "Sevgilinle buluştunuz!",
                "data": [
                    "type": "meeting",
                    "meetingId": meeting.id ?? "",
                    "latitude": meeting.latitude,
                    "longitude": meeting.longitude
                ]
            ]
            
            // Notifications collection'a ekle (Cloud Function tarafından işlenecek)
            try await db.collection("pendingNotifications").addDocument(data: notificationData)
            
        } catch {
            print("❌ Push bildirim hazırlama hatası: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Delete Meeting
    
    func deleteMeeting(_ meeting: MeetingEvent) async {
        guard let meetingId = meeting.id else { return }
        
        do {
            try await db.collection("meetingEvents").document(meetingId).delete()
            
            // Listeden kaldır
            meetingHistory.removeAll { $0.id == meetingId }
            
            // İstatistikleri yeniden hesapla
            calculateStatistics()
            
        } catch {
            print("❌ Buluşma silme hatası: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Formatted Statistics
    
    var formattedTotalMeetingTime: String {
        let hours = Int(totalMeetingTime / 3600)
        let minutes = Int((totalMeetingTime.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours) saat \(minutes) dakika"
        } else {
            return "\(minutes) dakika"
        }
    }
    
    var formattedAverageDuration: String {
        let minutes = Int(averageMeetingDuration / 60)
        
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours) sa \(remainingMinutes) dk"
        } else {
            return "\(minutes) dakika"
        }
    }
    
    var formattedMeetingDuration: String {
        let hours = Int(meetingDuration / 3600)
        let minutes = Int((meetingDuration.truncatingRemainder(dividingBy: 3600)) / 60)
        let seconds = Int(meetingDuration.truncatingRemainder(dividingBy: 60))
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        stopMeetingTimer()
        stopListeningToMeetingHistory()
        currentMeeting = nil
        meetingHistory = []
        isInMeeting = false
        meetingDuration = 0
    }
}
