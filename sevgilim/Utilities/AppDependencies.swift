//
//  AppDependencies.swift
//  sevgilim
//
//  Centralized dependency container for all app services
//  Replaces 19 separate @StateObject declarations in App
//

import Foundation
import Combine

@MainActor
final class AppDependencies: ObservableObject {
    
    // MARK: - Core Services (Eager - Always needed)
    let authService = AuthenticationService()
    let relationshipService = RelationshipService()
    let themeManager = ThemeManager()
    let navigationRouter = AppNavigationRouter()
    
    // MARK: - Feature Services
    // Note: These are eagerly initialized because .environmentObject() in sevgilimApp
    // forces immediate access. The actual Firestore listeners are started lazily via
    // staggered startup in MainTabView.startServicesStaggered().
    let memoryService = MemoryService()
    let photoService = PhotoService()
    let noteService = NoteService()
    let movieService = MovieService()
    let planService = PlanService()
    let placeService = PlaceService()
    let songService = SongService()
    let spotifyService = SpotifyService()
    let surpriseService = SurpriseService()
    let specialDayService = SpecialDayService()
    let storyService = StoryService()
    let messageService = MessageService()
    let greetingService = GreetingService()
    let secretVaultService = SecretVaultService()
    let moodService = MoodService()
    let proximityService = ProximityService()
    let notificationHistoryService = NotificationHistoryService()
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Convenience Accessors
    
    var currentUser: User? {
        authService.currentUser
    }
    
    var currentRelationship: Relationship? {
        relationshipService.currentRelationship
    }
    
    var relationshipId: String? {
        currentUser?.relationshipId
    }
    
    var userId: String? {
        currentUser?.id
    }
    
    // MARK: - Service Lifecycle
    
    func startCoreServices() {
        guard let relationshipId = relationshipId,
              let userId = userId else { return }
        
        relationshipService.listenToRelationship(relationshipId: relationshipId)
        print("🚀 Core services started for relationship: \(relationshipId)")
    }
    
    func startAllServices() {
        guard let relationshipId = relationshipId,
              let userId = userId else { return }
        
        // Core
        relationshipService.listenToRelationship(relationshipId: relationshipId)
        
        // Feature services
        memoryService.listenToMemories(relationshipId: relationshipId)
        photoService.listenToPhotos(relationshipId: relationshipId)
        noteService.listenToNotes(relationshipId: relationshipId)
        movieService.listenToMovies(relationshipId: relationshipId)
        planService.listenToPlans(relationshipId: relationshipId)
        placeService.listenToPlaces(relationshipId: relationshipId)
        songService.listenToSongs(relationshipId: relationshipId)
        surpriseService.listenToSurprises(relationshipId: relationshipId, userId: userId)
        specialDayService.listenToSpecialDays(relationshipId: relationshipId)
        storyService.listenToStories(relationshipId: relationshipId, currentUserId: userId)
        secretVaultService.listenToVault(relationshipId: relationshipId)
        moodService.listenToMoodStatuses(relationshipId: relationshipId)
        notificationHistoryService.listenToNotifications(userId: userId)
        
        // Proximity Service - Start if enabled (Wait for relationship data)
        relationshipService.$currentRelationship
            .compactMap { $0 }
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] relationship in
                guard let self = self else { return }
                
                if self.proximityService.proximityNotificationsEnabled {
                    let partnerId = relationship.partnerId(for: userId)
                    self.proximityService.startTracking(
                        userId: userId,
                        partnerId: partnerId,
                        relationshipId: relationshipId
                    )
                }
            }
            .store(in: &cancellables)
        
        print("🎬 All services started for relationship: \(relationshipId)")
        
        // Eski önbelleği temizle (30 günden eski)
        Task.detached(priority: .background) {
            await ImageCacheService.shared.clearOldCache()
        }
    }
    
    func stopAllServices() {
        cancellables.removeAll()
        relationshipService.stopListening()
        memoryService.stopListening()
        photoService.stopListening()
        noteService.stopListening()
        movieService.stopListening()
        planService.stopListening()
        placeService.stopListening()
        songService.stopListening()
        surpriseService.stopListening()
        specialDayService.stopListening()
        storyService.stopListening()
        secretVaultService.stopListening()
        moodService.stopListening()
        proximityService.stopTracking()
        notificationHistoryService.stopListening()
        
        print("🛑 All services stopped")
    }
    
    /// Çıkış yaparken tüm önbellekleri temizle
    func clearAllCaches() {
        OfflineDataManager.shared.clearAll()
        Task {
            await ImageCacheService.shared.clearCache()
        }
        VideoCacheService.shared.clearCache()
        OfflineSyncManager.shared.clearQueue()
        print("🗑️ Tüm önbellekler temizlendi")
    }
}
