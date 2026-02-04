//
//  HomeView.swift
//  sevgilim
//
//  Refactored: Components separated for better maintainability
//  Main home screen with relationship statistics and widgets

import SwiftUI
import Combine
import WidgetKit

struct HomeView: View {
    // MARK: - Environment Objects
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var greetingService: GreetingService
    @EnvironmentObject private var navigationRouter: AppNavigationRouter
    @EnvironmentObject private var proximityService: ProximityService
    @EnvironmentObject private var spotifyNowPlayingService: SpotifyNowPlayingService
    
    // MARK: - View Model
    @StateObject private var viewModel: HomeViewModel
    
    init(viewModel: HomeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    // MARK: - State
    @State private var currentDate = Date()
    @State private var showingMenu = false
    @State private var navigateToPlans = false
    @State private var navigateToMovies = false
    @State private var navigateToChat = false
    @State private var navigateToPlaces = false
    @State private var navigateToSongs = false
    @State private var navigateToSurprises = false
    @State private var navigateToSpecialDays = false
    @State private var showingNotifications = false
    @State private var navigateToSecretVault = false
    @State private var isUpdatingMood = false
    @State private var showingShareNowPlaying = false
    
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                AnimatedGradientBackground(theme: themeManager.currentTheme)
                    .ignoresSafeArea()
                
                // Content
                ScrollView {
                    VStack(spacing: 30) {
                        if let relationship = viewModel.relationship,
                           let currentUser = viewModel.currentUser {
                            
                            // Couple Header
                            CoupleHeaderCard(
                                user1Name: relationship.user1Name,
                                user2Name: relationship.user2Name
                            )
                            
                            // Story Circles (Instagram-style)
                            StoryCircles()
                                .padding(.horizontal, 20)
                            
                            // Partner Spotify Now Playing Card
                            if let partnerNowPlaying = spotifyNowPlayingService.partnerNowPlaying {
                                SpotifyNowPlayingCard(
                                    nowPlaying: partnerNowPlaying,
                                    partnerName: currentUser.id.map { relationship.partnerName(for: $0) } ?? "Sevgilin",
                                    theme: themeManager.currentTheme,
                                    onTap: {
                                        if let spotifyUrl = partnerNowPlaying.spotifyUrl,
                                           let url = URL(string: spotifyUrl) {
                                            UIApplication.shared.open(url)
                                        }
                                    }
                                )
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .move(edge: .top).combined(with: .opacity)
                                ))
                                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: spotifyNowPlayingService.partnerNowPlaying != nil)
                            }
                            
                            // Share Now Playing Button (kullanıcı şarkı paylaşabilir)
                            ShareNowPlayingButton {
                                showingShareNowPlaying = true
                            }
                            
                            // Dynamic Greeting (time-based)
                            if greetingService.shouldShowGreeting {
                                GreetingCard()
                            }
                            
                            // Partner Surprise
                            if let userId = currentUser.id,
                               let surprise = viewModel.nextUpcomingSurprise(for: userId) {
                                PartnerSurpriseHomeCard(
                                    surprise: surprise,
                                    onTap: { navigateToSurprises = true },
                                    onOpen: {
                                        Task {
                                            try? await viewModel.markSurpriseAsOpened(surprise)
                                        }
                                    }
                                )
                            }
                            
                            // Day Counter
                            DayCounterCard(
                                startDate: relationship.startDate,
                                currentDate: currentDate,
                                theme: themeManager.currentTheme
                            )
                            
                            // Partner Location
                            if proximityService.proximityNotificationsEnabled {
                                PartnerLocationCard(
                                    proximityService: proximityService,
                                    theme: themeManager.currentTheme
                                )
                            }
                            
                            MoodStatusWidget(
                                theme: themeManager.currentTheme,
                                currentUserName: currentUser.name,
                                partnerName: currentUser.id.map { relationship.partnerName(for: $0) },
                                currentMoodStatus: viewModel.currentMoodStatus,
                                partnerMoodStatus: viewModel.partnerMoodStatus,
                                isUpdating: isUpdatingMood,
                                onMoodSelected: { mood in
                                    guard !isUpdatingMood else { return }
                                    isUpdatingMood = true
                                    Task {
                                        await viewModel.updateMood(to: mood)
                                        await MainActor.run {
                                            isUpdatingMood = false
                                        }
                                    }
                                }
                            )
                            
                            // Quick Stats Grid
                            QuickStatsGrid(
                                photosCount: viewModel.photosCount,
                                memoriesCount: viewModel.memoriesCount,
                                notesCount: viewModel.notesCount,
                                plansCount: viewModel.plansCount,
                                theme: themeManager.currentTheme
                            )
                            
                            // Upcoming Special Day
                            if let nextDay = viewModel.nextSpecialDay,
                               nextDay.daysUntil <= 30 {
                                UpcomingSpecialDayWidget(
                                    specialDay: nextDay,
                                    onTap: { navigateToSpecialDays = true }
                                )
                            }
                            
                            // Recent Memories
                            if !viewModel.recentMemories.isEmpty {
                                RecentMemoriesCard(
                                    memories: Array(viewModel.recentMemories)
                                )
                            }
                            
                            // Upcoming Plans
                            if !viewModel.activePlans.isEmpty {
                                UpcomingPlansCard(
                                    plans: Array(viewModel.activePlans.prefix(3))
                                )
                            }
                            
                      
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 100) // Extra space for TabBar
                }
            }
            .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            showingNotifications = true
                        } label: {
                            Image(systemName: "bell")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingMenu = true
                        } label: {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 20, weight: .semibold))
    //                            .foregroundColor(.white)
                                .foregroundStyle(.white)
                        }
                            .buttonStyle(.plain)
    //                    .glassEffect()
                    }
                }
           .toolbarBackground(.hidden, for: .navigationBar)
            
            // Navigation Destinations
            .navigationDestination(isPresented: $navigateToPlans) { PlansView() }
            .navigationDestination(isPresented: $navigateToMovies) { MoviesView() }
            .navigationDestination(isPresented: $navigateToChat) {
                ChatView().environmentObject(viewModel.messageService)
            }
            .navigationDestination(isPresented: $navigateToPlaces) { PlacesView() }
            .navigationDestination(isPresented: $navigateToSongs) { SongsView() }
            .navigationDestination(isPresented: $navigateToSurprises) { SurprisesView() }
            .navigationDestination(isPresented: $navigateToSpecialDays) { SpecialDaysView() }
            .navigationDestination(isPresented: $navigateToSecretVault) { SecretVaultView() }
            
            // Hamburger Menu Sheet
            .sheet(isPresented: $showingMenu) {
                HamburgerMenuView(
                    onPlansSelected: { navigateWithDelay(to: $navigateToPlans) },
                    onMoviesSelected: { navigateWithDelay(to: $navigateToMovies) },
                    onChatSelected: { navigateWithDelay(to: $navigateToChat) },
                    onPlacesSelected: { navigateWithDelay(to: $navigateToPlaces) },
                    onSongsSelected: { navigateWithDelay(to: $navigateToSongs) },
                    onSurprisesSelected: { navigateWithDelay(to: $navigateToSurprises) },
                    onSpecialDaysSelected: { navigateWithDelay(to: $navigateToSpecialDays) },
                    onSecretVaultSelected: { navigateWithDelay(to: $navigateToSecretVault) }
                )
                .presentationDetents([.height(600)])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingNotifications) {
                NotificationsView()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingShareNowPlaying) {
                ShareNowPlayingView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .handleNavigationTriggers(
                router: navigationRouter,
                navigateToChat: $navigateToChat,
                navigateToSurprises: $navigateToSurprises,
                navigateToSpecialDays: $navigateToSpecialDays,
                navigateToPlans: $navigateToPlans,
                navigateToMovies: $navigateToMovies,
                navigateToSongs: $navigateToSongs,
                navigateToPlaces: $navigateToPlaces,
                navigateToSecretVault: $navigateToSecretVault
            )
            .checkNavigationTriggersOnAppear(
                router: navigationRouter,
                navigateToChat: $navigateToChat,
                navigateToSurprises: $navigateToSurprises,
                navigateToSpecialDays: $navigateToSpecialDays,
                navigateToPlans: $navigateToPlans,
                navigateToMovies: $navigateToMovies,
                navigateToSongs: $navigateToSongs,
                navigateToPlaces: $navigateToPlaces,
                navigateToSecretVault: $navigateToSecretVault
            )
         
            
            // Timer & Lifecycle
            .onReceive(timer) { _ in
                currentDate = Date()
            }
            .task {
                viewModel.startListeners()
                
                // Sync data to widget on initial load
                syncWidgetData()
            }
            .onChange(of: viewModel.relationship?.startDate) { _, _ in
                // Sync widget when relationship data changes
                syncWidgetData()
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Sync relationship data to widget
    private func syncWidgetData() {
        if let relationship = viewModel.relationship {
            SharedDataManager.shared.saveRelationshipData(
                user1Name: relationship.user1Name,
                user2Name: relationship.user2Name,
                startDate: relationship.startDate
            )
            WidgetCenter.shared.reloadAllTimelines()
            print("✅ Widget data synced: \(relationship.user1Name) & \(relationship.user2Name)")
        }
    }
    
    /// Navigate to a destination with delay (for menu dismissal animation)
    private func navigateWithDelay(to binding: Binding<Bool>) {
        showingMenu = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            binding.wrappedValue = true
        }
    }
}

