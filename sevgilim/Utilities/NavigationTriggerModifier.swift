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
            .onChange(of: router.pendingNavigation) { _, target in
                guard let target = target else { return }
                switch target {
                case .home:
                    if let tab = selectedTab { tab.wrappedValue = 0 }
                case .chat:
                    if let tab = selectedTab { tab.wrappedValue = 0 }
                    navigateToChat?.wrappedValue = true
                case .surprises:
                    if let tab = selectedTab { tab.wrappedValue = 0 }
                    navigateToSurprises?.wrappedValue = true
                case .specialDays:
                    if let tab = selectedTab { tab.wrappedValue = 0 }
                    navigateToSpecialDays?.wrappedValue = true
                case .plans:
                    if let tab = selectedTab { tab.wrappedValue = 0 }
                    navigateToPlans?.wrappedValue = true
                case .movies:
                    if let tab = selectedTab { tab.wrappedValue = 0 }
                    navigateToMovies?.wrappedValue = true
                case .songs:
                    if let tab = selectedTab { tab.wrappedValue = 0 }
                    navigateToSongs?.wrappedValue = true
                case .places:
                    if let tab = selectedTab { tab.wrappedValue = 0 }
                    navigateToPlaces?.wrappedValue = true
                case .secretVault:
                    if let tab = selectedTab { tab.wrappedValue = 0 }
                    navigateToSecretVault?.wrappedValue = true
                case .photos:
                    if let tab = selectedTab { tab.wrappedValue = 2 }
                    navigateToPhotos?.wrappedValue = true
                case .notes:
                    if let tab = selectedTab { tab.wrappedValue = 3 }
                    navigateToNotes?.wrappedValue = true
                case .memories:
                    if let tab = selectedTab { tab.wrappedValue = 1 }
                    navigateToMemories?.wrappedValue = true
                }
                router.clearNavigation()
            }
    }
    
    /// Checks pending navigation on appear and sets initial navigation state
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
            guard let target = router.pendingNavigation else { return }
            switch target {
            case .home:        break
            case .chat:        navigateToChat?.wrappedValue = true
            case .surprises:   navigateToSurprises?.wrappedValue = true
            case .specialDays: navigateToSpecialDays?.wrappedValue = true
            case .plans:       navigateToPlans?.wrappedValue = true
            case .movies:      navigateToMovies?.wrappedValue = true
            case .songs:       navigateToSongs?.wrappedValue = true
            case .places:      navigateToPlaces?.wrappedValue = true
            case .secretVault: navigateToSecretVault?.wrappedValue = true
            case .photos:      navigateToPhotos?.wrappedValue = true
            case .notes:       navigateToNotes?.wrappedValue = true
            case .memories:    navigateToMemories?.wrappedValue = true
            }
            router.clearNavigation()
        }
    }
}
