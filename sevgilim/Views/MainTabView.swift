//
//  MainTabView.swift
//  sevgilim
//

import SwiftUI

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
            startServices()
            handleNavigationTriggers()
        }
        .onChange(of: navigationRouter.chatTrigger) { _, _ in selectedTab = 0 }
        .onChange(of: navigationRouter.surprisesTrigger) { _, _ in selectedTab = 0 }
        .onChange(of: navigationRouter.specialDaysTrigger) { _, _ in selectedTab = 0 }
        .onChange(of: navigationRouter.moviesTrigger) { _, _ in selectedTab = 0 }
        .onChange(of: navigationRouter.plansTrigger) { _, _ in selectedTab = 0 }
        .onChange(of: navigationRouter.songsTrigger) { _, _ in selectedTab = 0 }
        .onChange(of: navigationRouter.placesTrigger) { _, _ in selectedTab = 0 }
        .onChange(of: navigationRouter.secretVaultTrigger) { _, _ in selectedTab = 0 }
        .onChange(of: navigationRouter.photosTrigger) { _, _ in selectedTab = 2 }
        .onChange(of: navigationRouter.notesTrigger) { _, _ in selectedTab = 3 }
        .onChange(of: navigationRouter.memoriesTrigger) { _, _ in selectedTab = 1 }
        .onChange(of: navigationRouter.locationTrigger) { _, _ in selectedTab = 0 }
    }
    
    private func startServices() {
        guard let currentUser = authService.currentUser,
              let userId = currentUser.id,
              let relationshipId = currentUser.relationshipId else { return }
        
        surpriseService.listenToSurprises(relationshipId: relationshipId, userId: userId)
        memoryService.listenToMemories(relationshipId: relationshipId)
        photoService.listenToPhotos(relationshipId: relationshipId)
        noteService.listenToNotes(relationshipId: relationshipId)
        planService.listenToPlans(relationshipId: relationshipId)
        movieService.listenToMovies(relationshipId: relationshipId)
        placeService.listenToPlaces(relationshipId: relationshipId)
        songService.listenToSongs(relationshipId: relationshipId)
        storyService.listenToStories(relationshipId: relationshipId, currentUserId: userId)
        secretVaultService.listenToVault(relationshipId: relationshipId)
        
        print("🎬 Tüm servisler başlatıldı")
    }
    
    private func handleNavigationTriggers() {
        if navigationRouter.chatTrigger > 0 { selectedTab = 0 }
        if navigationRouter.surprisesTrigger > 0 { selectedTab = 0 }
        if navigationRouter.specialDaysTrigger > 0 { selectedTab = 0 }
        if navigationRouter.moviesTrigger > 0 { selectedTab = 0 }
        if navigationRouter.plansTrigger > 0 { selectedTab = 0 }
        if navigationRouter.songsTrigger > 0 { selectedTab = 0 }
        if navigationRouter.placesTrigger > 0 { selectedTab = 0 }
        if navigationRouter.secretVaultTrigger > 0 { selectedTab = 0 }
        if navigationRouter.photosTrigger > 0 { selectedTab = 2 }
        if navigationRouter.notesTrigger > 0 { selectedTab = 3 }
        if navigationRouter.memoriesTrigger > 0 { selectedTab = 1 }
        if navigationRouter.locationTrigger > 0 { selectedTab = 0 }
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
