//
//  NavigationDestination.swift
//  sevgilim
//
//  Enum-based navigation destinations for type-safe navigation
//  Replaces multiple boolean @State flags with single NavigationPath
//

import Foundation

/// Main navigation destinations from HomeView
enum HomeDestination: Hashable {
    case chat
    case surprises
    case specialDays
    case plans
    case movies
    case songs
    case places
    case secretVault
    case notifications
}

/// Tab-based navigation destinations
enum TabDestination: Hashable {
    case home
    case memories
    case photos
    case notes
    case profile
}

