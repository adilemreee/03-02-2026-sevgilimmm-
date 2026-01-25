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
    
    // MARK: - Feature Services (Lazy - Loaded when needed)
    lazy var memoryService = MemoryService()
    lazy var photoService = PhotoService()
    lazy var noteService = NoteService()
    lazy var movieService = MovieService()
    lazy var planService = PlanService()
    lazy var placeService = PlaceService()
    lazy var songService = SongService()
    lazy var spotifyService = SpotifyService()
    lazy var surpriseService = SurpriseService()
    lazy var specialDayService = SpecialDayService()
    lazy var storyService = StoryService()
    lazy var messageService = MessageService()
    lazy var greetingService = GreetingService()
    lazy var secretVaultService = SecretVaultService()
    lazy var moodService = MoodService()
    
    // MARK: - Location Services (Singleton)
    var locationService: LocationService { LocationService.shared }
    lazy var meetingService = MeetingService()
    lazy var locationViewModel = LocationViewModel()
    
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
        
        // Location services - configure ile başlat
        locationService.configure(userId: userId, relationshipId: relationshipId)
        meetingService.configure(relationshipId: relationshipId)
        
        print("🎬 All services started for relationship: \(relationshipId)")
    }
    
    func stopAllServices() {
        relationshipService.stopListening()
        memoryService.stopListening()
        photoService.stopListening()
        noteService.stopListening()
        movieService.stopListening()
        planService.stopListening()
        placeService.stopListening()
        songService.stopListening()
        surpriseService.stopListening()
        storyService.stopListening()
        secretVaultService.stopListening()
        
        // Stop location services
        locationService.stopSharingLocation()
        
        print("🛑 All services stopped")
    }
}
