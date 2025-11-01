//
//  HomeView.swift
//  sevgilim
//
//  Refactored: Components separated for better maintainability
//  Main home screen with relationship statistics and widgets

import SwiftUI
import Combine

struct HomeView: View {
    // MARK: - Environment Objects
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var greetingService: GreetingService
    @EnvironmentObject private var messageService: MessageService
    
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
                    .padding(.bottom, 30)
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
         
            
            // Timer & Lifecycle
            .onReceive(timer) { _ in
                currentDate = Date()
            }
            .task {
                viewModel.startListeners()
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Navigate to a destination with delay (for menu dismissal animation)
    private func navigateWithDelay(to binding: Binding<Bool>) {
        showingMenu = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            binding.wrappedValue = true
        }
    }
    

    
}
