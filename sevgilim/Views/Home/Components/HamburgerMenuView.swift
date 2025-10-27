//
//  HamburgerMenuView.swift
//  sevgilim
//
//  Created by refactoring HomeView
//  Minimal menu with feature counts

import SwiftUI

struct HamburgerMenuView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var planService: PlanService
    @EnvironmentObject var movieService: MovieService
    @EnvironmentObject var placeService: PlaceService
    @EnvironmentObject var songService: SongService
    @EnvironmentObject var surpriseService: SurpriseService
    @EnvironmentObject var specialDayService: SpecialDayService
    @EnvironmentObject var messageService: MessageService
    @EnvironmentObject var secretVaultService: SecretVaultService
    
    let onPlansSelected: () -> Void
    let onMoviesSelected: () -> Void
    let onChatSelected: () -> Void
    let onPlacesSelected: () -> Void
    let onSongsSelected: () -> Void
    let onSurprisesSelected: () -> Void
    let onSpecialDaysSelected: () -> Void
    let onSecretVaultSelected: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag Handle
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 8)
            
            // Header
            VStack(spacing: 4) {
                Text("Menü")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [themeManager.currentTheme.primaryColor, themeManager.currentTheme.accentColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            
            }
            .padding(.top, 24)
            .padding(.bottom, 24)
            
            // Menu Items - Minimal Design
            VStack(spacing: 12) {
                MinimalMenuButton(
                    icon: "message.fill",
                    title: "Sohbet",
                    count: messageService.unreadMessageCount,
                    theme: themeManager.currentTheme,
                    action: onChatSelected
                )
                
                MinimalMenuButton(
                    icon: "gift.fill",
                    title: "Sürprizler",
                    count: surpriseService.surprises.count,
                    theme: themeManager.currentTheme,
                    action: onSurprisesSelected
                )
                
            
                
                MinimalMenuButton(
                    icon: "calendar.badge.clock",
                    title: "Özel Günler",
                    count: specialDayService.specialDays.count,
                    theme: themeManager.currentTheme,
                    action: onSpecialDaysSelected
                )
                
                MinimalMenuButton(
                    icon: "calendar",
                    title: "Planlar",
                    count: planService.plans.count,
                    theme: themeManager.currentTheme,
                    action: onPlansSelected
                )
                
                MinimalMenuButton(
                    icon: "film.fill",
                    title: "Filmler",
                    count: movieService.movies.count,
                    theme: themeManager.currentTheme,
                    action: onMoviesSelected
                )
                
                MinimalMenuButton(
                    icon: "map.fill",
                    title: "Yerler",
                    count: placeService.places.count,
                    theme: themeManager.currentTheme,
                    action: onPlacesSelected
                )
                
                MinimalMenuButton(
                    icon: "music.note.list",
                    title: "Şarkılar",
                    count: songService.songs.count,
                    theme: themeManager.currentTheme,
                    action: onSongsSelected
                )
                
                MinimalMenuButton(
                    icon: "lock.shield.fill",
                    title: "Özelll",
                    count: secretVaultService.items.count,
                    theme: themeManager.currentTheme,
                    action: onSecretVaultSelected
                )
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - Menu Button

struct MinimalMenuButton: View {
    let icon: String
    let title: String
    var count: Int?
    let theme: AppTheme
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(theme.primaryColor)
                    .frame(width: 24)
                
                // Title
                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Count Badge (if available)
                if let count = count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.primaryColor.opacity(0.8))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(theme.primaryColor.opacity(0.12))
                        .clipShape(Capsule())
                }
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isPressed ? Color(.systemGray6) : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color(.systemGray5).opacity(0.5), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}
