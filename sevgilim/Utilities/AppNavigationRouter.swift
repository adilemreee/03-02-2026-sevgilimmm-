//
//  AppNavigationRouter.swift
//  sevgilim
//
//  Handles global navigation triggers such as deep links from notifications.
//

import Foundation
import Combine

/// Global navigation coordinator that lets services trigger screens without
/// tightly coupling to view hierarchy.
@MainActor
final class AppNavigationRouter: ObservableObject {
    
    // MARK: - Navigation Target Enum
    enum NavigationTarget: Equatable {
        case home
        case chat
        case surprises
        case specialDays
        case plans
        case movies
        case notes
        case photos
        case songs
        case places
        case secretVault
        case memories
    }
    
    /// Single published property — replaces 11 separate @Published Int triggers.
    /// Views observe this one property and react via .onChange(of:).
    @Published private(set) var pendingNavigation: NavigationTarget?
    
    /// Tab bar visibility control
    @Published var hideTabBar: Bool = false
    
    // MARK: - Navigation Methods
    
    func openHome()        { pendingNavigation = .home }
    func openChat()        { pendingNavigation = .chat }
    func openSurprises()   { pendingNavigation = .surprises }
    func openSpecialDays() { pendingNavigation = .specialDays }
    func openPlans()       { pendingNavigation = .plans }
    func openMovies()      { pendingNavigation = .movies }
    func openNotes()       { pendingNavigation = .notes }
    func openPhotos()      { pendingNavigation = .photos }
    func openSongs()       { pendingNavigation = .songs }
    func openPlaces()      { pendingNavigation = .places }
    func openSecretVault() { pendingNavigation = .secretVault }
    func openMemories()    { pendingNavigation = .memories }

    static func target(forNotificationType rawType: String) -> NavigationTarget? {
        switch rawType.lowercased() {
        case "message_new", "story_reply", "inactive_couple_nudge":
            return .chat
        case "surprise_new", "surprise_reveal_due", "surprise_opened", "special_day_surprise_missing":
            return .surprises
        case "special_day_upcoming", "special_day_new", "special_day_update", "special_day_reminder":
            return .specialDays
        case "plan_new", "plan_update", "plan_reminder", "plan_tomorrow", "plan_completed", "special_day_plan_missing":
            return .plans
        case "movie_night", "movie_new":
            return .movies
        case "note_shared", "note_new", "note_update":
            return .notes
        case "photo_added", "photo_new":
            return .photos
        case "song_shared", "song_new":
            return .songs
        case "place_recommendation", "place_new":
            return .places
        case "secret_vault_alert", "secret_vault_new":
            return .secretVault
        case "memory_new", "memory_comment", "memory_like", "on_this_day_memory":
            return .memories
        case "story_new", "story_like", "mood_update":
            return .home
        default:
            return nil
        }
    }

    func open(notificationType: String) {
        guard let target = Self.target(forNotificationType: notificationType) else {
            return
        }

        switch target {
        case .home: openHome()
        case .chat: openChat()
        case .surprises: openSurprises()
        case .specialDays: openSpecialDays()
        case .plans: openPlans()
        case .movies: openMovies()
        case .notes: openNotes()
        case .photos: openPhotos()
        case .songs: openSongs()
        case .places: openPlaces()
        case .secretVault: openSecretVault()
        case .memories: openMemories()
        }
    }
    
    /// Call after handling navigation to reset state
    func clearNavigation() { pendingNavigation = nil }
}
