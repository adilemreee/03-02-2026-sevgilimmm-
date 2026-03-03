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
    
    /// Call after handling navigation to reset state
    func clearNavigation() { pendingNavigation = nil }
}
