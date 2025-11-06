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
    
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(
                viewModel: HomeViewModel(
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
            )
                .tag(0)
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                    Text("Anasayfa")
                }
            
            MemoriesView()
                .tag(1)
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "heart.text.square.fill" : "heart.text.square")
                    Text("Anılar")
                }
            
            PhotosView()
                .tag(2)
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "photo.fill" : "photo")
                    Text("Fotoğraflar")
                }
            
            NotesView()
                .tag(3)
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "note.text" : "note.text")
                    Text("Notlar")
                }
            
            ProfileView()
                .tag(4)
                .tabItem {
                    Image(systemName: selectedTab == 4 ? "person.fill" : "person")
                    Text("Profil")
                }
        }
        .accentColor(themeManager.currentTheme.primaryColor)
        .onAppear {
            // Tüm servislerin listener'larını başlat
            if let currentUser = authService.currentUser,
               let userId = currentUser.id,
               let relationshipId = currentUser.relationshipId {
                
                // Sürpriz servisini başlat
                surpriseService.listenToSurprises(relationshipId: relationshipId, userId: userId)
                
                // Diğer servisleri de başlat
                memoryService.listenToMemories(relationshipId: relationshipId)
                photoService.listenToPhotos(relationshipId: relationshipId)
                noteService.listenToNotes(relationshipId: relationshipId)
                planService.listenToPlans(relationshipId: relationshipId)
                movieService.listenToMovies(relationshipId: relationshipId)
                placeService.listenToPlaces(relationshipId: relationshipId)
                songService.listenToSongs(relationshipId: relationshipId)
                storyService.listenToStories(relationshipId: relationshipId, currentUserId: userId)
                secretVaultService.listenToVault(relationshipId: relationshipId)
                // messageService.listenToMessages() kaldırıldı - ChatView açıldığında başlayacak
                
                print("🎬 Tüm servisler başlatıldı - Story listener aktif")
            }
            
            if navigationRouter.chatTrigger > 0 {
                selectedTab = 0
            }
            
            if navigationRouter.surprisesTrigger > 0 {
                selectedTab = 0
            }
            
            if navigationRouter.specialDaysTrigger > 0 {
                selectedTab = 0
            }
            if navigationRouter.moviesTrigger > 0 {
                selectedTab = 0
            }
            if navigationRouter.plansTrigger > 0 {
                selectedTab = 0
            }
            if navigationRouter.songsTrigger > 0 {
                selectedTab = 0
            }
            if navigationRouter.placesTrigger > 0 {
                selectedTab = 0
            }
            if navigationRouter.secretVaultTrigger > 0 {
                selectedTab = 0
            }
            if navigationRouter.photosTrigger > 0 {
                selectedTab = 2
            }
            if navigationRouter.notesTrigger > 0 {
                selectedTab = 3
            }
            if navigationRouter.memoriesTrigger > 0 {
                selectedTab = 1
            }
        }
        .onChange(of: navigationRouter.chatTrigger) { _ in
            selectedTab = 0
        }
        .onChange(of: navigationRouter.surprisesTrigger) { _ in
            selectedTab = 0
        }
        .onChange(of: navigationRouter.specialDaysTrigger) { _ in
            selectedTab = 0
        }
        .onChange(of: navigationRouter.moviesTrigger) { _ in
            selectedTab = 0
        }
        .onChange(of: navigationRouter.plansTrigger) { _ in
            selectedTab = 0
        }
        .onChange(of: navigationRouter.songsTrigger) { _ in
            selectedTab = 0
        }
        .onChange(of: navigationRouter.placesTrigger) { _ in
            selectedTab = 0
        }
        .onChange(of: navigationRouter.secretVaultTrigger) { _ in
            selectedTab = 0
        }
        .onChange(of: navigationRouter.photosTrigger) { _ in
            selectedTab = 2
        }
        .onChange(of: navigationRouter.notesTrigger) { _ in
            selectedTab = 3
        }
        .onChange(of: navigationRouter.memoriesTrigger) { _ in
            selectedTab = 1
        }
    }
}
