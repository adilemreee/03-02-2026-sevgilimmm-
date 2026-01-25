//
//  NavigationTriggerModifier.swift
//  sevgilim
//
//  Reduces code duplication for navigation trigger handling across views.
//

import SwiftUI

// MARK: - Navigation Trigger Handler Extension
extension View {
    /// Handles all navigation triggers from AppNavigationRouter and maps them to tab selection or navigation states
    func handleNavigationTriggers(
        router: AppNavigationRouter,
        selectedTab: Binding<Int>? = nil,
        navigateToChat: Binding<Bool>? = nil,
        navigateToSurprises: Binding<Bool>? = nil,
        navigateToSpecialDays: Binding<Bool>? = nil,
        navigateToPlans: Binding<Bool>? = nil,
        navigateToMovies: Binding<Bool>? = nil,
        navigateToSongs: Binding<Bool>? = nil,
        navigateToPlaces: Binding<Bool>? = nil,
        navigateToSecretVault: Binding<Bool>? = nil,
        navigateToPhotos: Binding<Bool>? = nil,
        navigateToNotes: Binding<Bool>? = nil,
        navigateToMemories: Binding<Bool>? = nil
    ) -> some View {
        self
            .onChange(of: router.chatTrigger) { _, _ in
                if let tab = selectedTab { tab.wrappedValue = 0 }
                navigateToChat?.wrappedValue = true
            }
            .onChange(of: router.surprisesTrigger) { _, _ in
                if let tab = selectedTab { tab.wrappedValue = 0 }
                navigateToSurprises?.wrappedValue = true
            }
            .onChange(of: router.specialDaysTrigger) { _, _ in
                if let tab = selectedTab { tab.wrappedValue = 0 }
                navigateToSpecialDays?.wrappedValue = true
            }
            .onChange(of: router.plansTrigger) { _, _ in
                if let tab = selectedTab { tab.wrappedValue = 0 }
                navigateToPlans?.wrappedValue = true
            }
            .onChange(of: router.moviesTrigger) { _, _ in
                if let tab = selectedTab { tab.wrappedValue = 0 }
                navigateToMovies?.wrappedValue = true
            }
            .onChange(of: router.songsTrigger) { _, _ in
                if let tab = selectedTab { tab.wrappedValue = 0 }
                navigateToSongs?.wrappedValue = true
            }
            .onChange(of: router.placesTrigger) { _, _ in
                if let tab = selectedTab { tab.wrappedValue = 0 }
                navigateToPlaces?.wrappedValue = true
            }
            .onChange(of: router.secretVaultTrigger) { _, _ in
                if let tab = selectedTab { tab.wrappedValue = 0 }
                navigateToSecretVault?.wrappedValue = true
            }
            .onChange(of: router.photosTrigger) { _, _ in
                if let tab = selectedTab { tab.wrappedValue = 2 }
                navigateToPhotos?.wrappedValue = true
            }
            .onChange(of: router.notesTrigger) { _, _ in
                if let tab = selectedTab { tab.wrappedValue = 3 }
                navigateToNotes?.wrappedValue = true
            }
            .onChange(of: router.memoriesTrigger) { _, _ in
                if let tab = selectedTab { tab.wrappedValue = 1 }
                navigateToMemories?.wrappedValue = true
            }
    }
    
    /// Checks all navigation triggers on appear and sets initial navigation state
    func checkNavigationTriggersOnAppear(
        router: AppNavigationRouter,
        navigateToChat: Binding<Bool>? = nil,
        navigateToSurprises: Binding<Bool>? = nil,
        navigateToSpecialDays: Binding<Bool>? = nil,
        navigateToPlans: Binding<Bool>? = nil,
        navigateToMovies: Binding<Bool>? = nil,
        navigateToSongs: Binding<Bool>? = nil,
        navigateToPlaces: Binding<Bool>? = nil,
        navigateToSecretVault: Binding<Bool>? = nil,
        navigateToPhotos: Binding<Bool>? = nil,
        navigateToNotes: Binding<Bool>? = nil,
        navigateToMemories: Binding<Bool>? = nil
    ) -> some View {
        self.onAppear {
            if router.chatTrigger > 0 { navigateToChat?.wrappedValue = true }
            if router.surprisesTrigger > 0 { navigateToSurprises?.wrappedValue = true }
            if router.specialDaysTrigger > 0 { navigateToSpecialDays?.wrappedValue = true }
            if router.plansTrigger > 0 { navigateToPlans?.wrappedValue = true }
            if router.moviesTrigger > 0 { navigateToMovies?.wrappedValue = true }
            if router.songsTrigger > 0 { navigateToSongs?.wrappedValue = true }
            if router.placesTrigger > 0 { navigateToPlaces?.wrappedValue = true }
            if router.secretVaultTrigger > 0 { navigateToSecretVault?.wrappedValue = true }
            if router.photosTrigger > 0 { navigateToPhotos?.wrappedValue = true }
            if router.notesTrigger > 0 { navigateToNotes?.wrappedValue = true }
            if router.memoriesTrigger > 0 { navigateToMemories?.wrappedValue = true }
        }
    }
}
