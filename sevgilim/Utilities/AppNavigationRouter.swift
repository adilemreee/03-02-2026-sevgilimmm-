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
final class AppNavigationRouter: ObservableObject {
    /// Increments every time chat should be presented.
    @Published private(set) var chatTrigger: Int = 0
    @Published private(set) var surprisesTrigger: Int = 0
    @Published private(set) var specialDaysTrigger: Int = 0
    @Published private(set) var plansTrigger: Int = 0
    @Published private(set) var moviesTrigger: Int = 0
    @Published private(set) var notesTrigger: Int = 0
    @Published private(set) var photosTrigger: Int = 0
    @Published private(set) var songsTrigger: Int = 0
    @Published private(set) var placesTrigger: Int = 0
    @Published private(set) var secretVaultTrigger: Int = 0
    @Published private(set) var memoriesTrigger: Int = 0
    
    /// Requests navigation to the chat screen.
    func openChat() {
        DispatchQueue.main.async {
            self.chatTrigger &+= 1
        }
    }
    
    func openSurprises() {
        DispatchQueue.main.async {
            self.surprisesTrigger &+= 1
        }
    }
    
    func openSpecialDays() {
        DispatchQueue.main.async {
            self.specialDaysTrigger &+= 1
        }
    }
    
    func openPlans() {
        DispatchQueue.main.async {
            self.plansTrigger &+= 1
        }
    }
    
    func openMovies() {
        DispatchQueue.main.async {
            self.moviesTrigger &+= 1
        }
    }
    
    func openNotes() {
        DispatchQueue.main.async {
            self.notesTrigger &+= 1
        }
    }
    
    func openPhotos() {
        DispatchQueue.main.async {
            self.photosTrigger &+= 1
        }
    }
    
    func openSongs() {
        DispatchQueue.main.async {
            self.songsTrigger &+= 1
        }
    }
    
    func openPlaces() {
        DispatchQueue.main.async {
            self.placesTrigger &+= 1
        }
    }
    
    func openSecretVault() {
        DispatchQueue.main.async {
            self.secretVaultTrigger &+= 1
        }
    }
    
    func openMemories() {
        DispatchQueue.main.async {
            self.memoriesTrigger &+= 1
        }
    }
}
