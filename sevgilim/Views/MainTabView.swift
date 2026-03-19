//
//  MainTabView.swift
//  sevgilim
//

import SwiftUI
import UIKit
import UserNotifications

struct MainTabView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var relationshipService: RelationshipService
    @EnvironmentObject var surpriseService: SurpriseService
    @EnvironmentObject var specialDayService: SpecialDayService
    @EnvironmentObject var memoryService: MemoryService
    @EnvironmentObject var photoService: PhotoService
    @EnvironmentObject var noteService: NoteService
    @EnvironmentObject var planService: PlanService
    @EnvironmentObject var movieService: MovieService
    @EnvironmentObject var placeService: PlaceService
    @EnvironmentObject var songService: SongService
    @EnvironmentObject var storyService: StoryService
    @EnvironmentObject var messageService: MessageService
    @EnvironmentObject var secretVaultService: SecretVaultService
    @EnvironmentObject var moodService: MoodService
    @EnvironmentObject var proximityService: ProximityService
    @EnvironmentObject var notificationHistoryService: NotificationHistoryService
    @EnvironmentObject var navigationRouter: AppNavigationRouter
    
    // MARK: - Cached ViewModel (prevents recreation on tab switch)
    @State private var homeViewModel: HomeViewModel?
    
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Content with bottom padding for tab bar
            Group {
                switch selectedTab {
                case 0:
                    if let viewModel = homeViewModel {
                        HomeView(viewModel: viewModel)
                    } else {
                        ProgressView()
                            .onAppear { createHomeViewModel() }
                    }
                case 1:
                    MemoriesView()
                case 2:
                    PhotosView()
                case 3:
                    NotesView()
                case 4:
                    ProfileView()
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .top) {
                // Çevrimdışı banner - üstte göster
                OfflineBannerView()
            }
            .safeAreaInset(edge: .bottom) {
                // Tab bar için boşluk - sadece tab bar görünürken
                Color.clear.frame(height: navigationRouter.hideTabBar ? 0 : 70)
                    .animation(.spring(response: 0.15, dampingFraction: 0.9), value: navigationRouter.hideTabBar)
            }
            
            // Floating Pill Tab Bar
            VStack(spacing: 0) {
                Spacer()
                if !navigationRouter.hideTabBar {
                    PillTabBar(
                        selectedTab: $selectedTab,
                        theme: themeManager.currentTheme
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                }
            }
            .animation(.spring(response: 0.15, dampingFraction: 0.9), value: navigationRouter.hideTabBar)
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            startServicesStaggered()
            handlePendingNavigation()
            syncNotificationBadge(authService.currentUser?.unreadNotificationCount ?? 0)
        }
        // Single consolidated onChange for navigation — replaces 11 separate onChange listeners
        .onChange(of: navigationRouter.pendingNavigation) { _, target in
            guard let target = target else { return }
            switch target {
            case .home, .chat, .surprises, .specialDays, .movies, .plans, .songs, .places, .secretVault:
                selectedTab = 0
            case .photos:
                selectedTab = 2
            case .notes:
                selectedTab = 3
            case .memories:
                selectedTab = 1
            }
            // Clear after handling
            navigationRouter.clearNavigation()
        }
        .onReceive(relationshipService.$currentRelationship) { relationship in
            if let relationship = relationship,
               let currentUser = authService.currentUser,
               let userId = currentUser.id,
               let relationshipId = currentUser.relationshipId {
                
                if proximityService.proximityNotificationsEnabled {
                    let partnerId = relationship.partnerId(for: userId)
                    proximityService.startTracking(userId: userId, partnerId: partnerId, relationshipId: relationshipId)
                }
            }
        }
        .onChange(of: authService.currentUser?.unreadNotificationCount ?? 0) { _, unreadCount in
            syncNotificationBadge(unreadCount)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            syncNotificationBadge(authService.currentUser?.unreadNotificationCount ?? 0)
        }
    }
    
    /// Staggered service start to avoid CPU spike on launch
    /// Phase 1 (immediate): Critical services for UI display
    /// Phase 2 (0.3s delay): Secondary data services
    /// Phase 3 (0.8s delay): Background/optional services
    private func startServicesStaggered() {
        guard let currentUser = authService.currentUser,
              let userId = currentUser.id,
              let relationshipId = currentUser.relationshipId else { return }
        
        // Phase 1: Critical — needed for home screen immediately
        relationshipService.listenToRelationship(relationshipId: relationshipId)
        surpriseService.listenToSurprises(relationshipId: relationshipId, userId: userId)
        notificationHistoryService.listenToNotifications(userId: userId)
        
        // Phase 2: Secondary data — needed when user scrolls or switches tabs
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
            memoryService.listenToMemories(relationshipId: relationshipId)
            photoService.listenToPhotos(relationshipId: relationshipId)
            noteService.listenToNotes(relationshipId: relationshipId)
            print("📦 Phase 2 servisler başlatıldı")
        }
        
        // Phase 3: Background services — can wait
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s
            planService.listenToPlans(relationshipId: relationshipId)
            movieService.listenToMovies(relationshipId: relationshipId)
            placeService.listenToPlaces(relationshipId: relationshipId)
            songService.listenToSongs(relationshipId: relationshipId)
            storyService.listenToStories(relationshipId: relationshipId, currentUserId: userId)
            secretVaultService.listenToVault(relationshipId: relationshipId)
            print("🎬 Phase 3 servisler başlatıldı — Tüm servisler hazır")
        }
    }
    
    private func handlePendingNavigation() {
        guard let target = navigationRouter.pendingNavigation else { return }
        switch target {
        case .home, .chat, .surprises, .specialDays, .movies, .plans, .songs, .places, .secretVault:
            selectedTab = 0
        case .photos:
            selectedTab = 2
        case .notes:
            selectedTab = 3
        case .memories:
            selectedTab = 1
        }
        navigationRouter.clearNavigation()
    }
    
    // MARK: - ViewModel Factory
    private func createHomeViewModel() {
        guard homeViewModel == nil else { return }
        homeViewModel = HomeViewModel(
            authService: authService,
            relationshipService: relationshipService,
            memoryService: memoryService,
            photoService: photoService,
            noteService: noteService,
            planService: planService,
            surpriseService: surpriseService,
            specialDayService: specialDayService,
            messageService: messageService,
            moodService: moodService
        )
    }
    
    private func syncNotificationBadge(_ count: Int) {
        let safeCount = max(count, 0)
        
        if #available(iOS 17.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(safeCount) { error in
                if let error = error {
                    print("Rozet eşitleme hatası: \(error.localizedDescription)")
                }
            }
        } else {
            UIApplication.shared.applicationIconBadgeNumber = safeCount
        }
    }
}

// MARK: - Pill Tab Bar Component
struct PillTabBar: View {
    @Binding var selectedTab: Int
    let theme: AppTheme
    @Namespace private var pillAnimation
    
    private var tabs: [(icon: String, label: String)] {
        [
            ("house.fill", "Ana"),
            ("heart.fill", "Anılar"),
            ("photo.fill", "Foto"),
            ("note.text", "Notlar"),
            ("person.fill", "Profil")
        ]
    }
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<tabs.count, id: \.self) { index in
                let isSelected = selectedTab == index
                
                Button {
                    // Trigger haptic instantly
                    HapticManager.shared.selection()
                    
                    // Update state without global animation to prevent heavy view transition lag
                    // The .animation modifier below will handle the smooth pill movement
                    selectedTab = index
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tabs[index].icon)
                            .font(.system(size: 16, weight: .semibold))
                        
                        if isSelected {
                            Text(tabs[index].label)
                                .font(.system(size: 13, weight: .semibold))
                                .fixedSize() // Prevents layout jumping
                        }
                    }
                    .foregroundStyle(isSelected ? .white : .primary.opacity(0.6))
                    .padding(.horizontal, isSelected ? 16 : 14)
                    .padding(.vertical, 12)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            theme.primaryColor,
                                            theme.secondaryColor
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .matchedGeometryEffect(id: "pill", in: pillAnimation)
                                .shadow(color: theme.primaryColor.opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
                .overlay {
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.4), .white.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                }
        }
        .compositingGroup() // GPU acceleration: flattens the view before applying effects
        .contentShape(Capsule())
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        // Enable smooth animation for layout changes (pill movement) inside this view
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: selectedTab)
    }
}
