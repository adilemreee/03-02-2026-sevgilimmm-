//
//  SongsView.swift
//  sevgilim
//

import SwiftUI

struct SongsView: View {
    @EnvironmentObject var songService: SongService
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var showingAddSong = false
    @State private var searchText = ""
    @State private var selectedSong: Song?
    
    var filteredSongs: [Song] {
        if searchText.isEmpty {
            return songService.songs
        } else {
            return songService.songs.filter { song in
                song.title.localizedCaseInsensitiveContains(searchText) ||
                song.artist.localizedCaseInsensitiveContains(searchText) ||
                (song.note?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        themeManager.currentTheme.primaryColor.opacity(0.3),
                        themeManager.currentTheme.secondaryColor.opacity(0.2)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 24))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Şarkılarımız")
                                .font(.title3)
                                .fontWeight(.bold)
                            
                            Text("Birlikte dinlediğimiz şarkılar")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 15)
                    
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Şarkı ara...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 15)
                    
                    // Content
                    if songService.songs.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "music.note")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary.opacity(0.6))
                            
                            VStack(spacing: 8) {
                                Text("Henüz şarkı eklenmemiş")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Birlikte dinlediğiniz şarkıları ekleyin")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            
                            Button(action: { showingAddSong = true }) {
                                Label("İlk Şarkıyı Ekle", systemImage: "plus.circle.fill")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(themeManager.currentTheme.primaryColor)
                                    .cornerRadius(12)
                            }
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredSongs) { song in
                                    SongCard(song: song) {
                                        selectedSong = song
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 100) // Extra space for TabBar
                        }
                    }
                }
                
                // Loading Overlay
                if songService.isLoading {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Yükleniyor...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15))
                }
                
                // Floating Add Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showingAddSong = true }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(themeManager.currentTheme.primaryColor)
                                .clipShape(Circle())
                                .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 100) // Above TabBar
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showingAddSong) {
            AddSongView()
                .environmentObject(songService)
                .environmentObject(authService)
                .environmentObject(themeManager)
        }
        .sheet(item: $selectedSong) { song in
            SongDetailView(song: song)
                .environmentObject(songService)
                .environmentObject(themeManager)
        }
        .onAppear {
            if let relationshipId = authService.currentUser?.relationshipId {
                songService.listenToSongs(relationshipId: relationshipId)
            }
        }
    }
}

// MARK: - Song Card
struct SongCard: View {
    let song: Song
    let onTap: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 15) {
                // Album Cover or Music Icon
                if let imageUrl = song.imageUrl, !imageUrl.isEmpty {
                    AsyncImage(url: URL(string: imageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ZStack {
                            Rectangle()
                                .fill(themeManager.currentTheme.primaryColor.opacity(0.15))
                            ProgressView()
                        }
                    }
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)
                } else {
                    ZStack {
                        Circle()
                            .fill(themeManager.currentTheme.primaryColor.opacity(0.15))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "music.note")
                            .font(.title2)
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                    }
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(song.artist)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Text(song.date, formatter: DateFormatter.displayFormat)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Link Buttons
                HStack(spacing: 8) {
                    if let spotifyLink = song.spotifyLink, !spotifyLink.isEmpty {
                        Button(action: {
                            openURL(spotifyLink)
                        }) {
                            Image(systemName: "music.note")
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(6)
                                .background(Color.green.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    
                    if let appleMusicLink = song.appleMusicLink, !appleMusicLink.isEmpty {
                        Button(action: {
                            openURL(appleMusicLink)
                        }) {
                            Image(systemName: "music.note.house")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(6)
                                .background(Color.red.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    
                    if let youtubeLink = song.youtubeLink, !youtubeLink.isEmpty {
                        Button(action: {
                            openURL(youtubeLink)
                        }) {
                            Image(systemName: "play.circle")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(6)
                                .background(Color.red.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Song Detail View
struct SongDetailView: View {
    let song: Song
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var songService: SongService
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Song Info Section
                    VStack(spacing: 15) {
                        // Album Cover or Music Icon
                        if let imageUrl = song.imageUrl, !imageUrl.isEmpty {
                            AsyncImage(url: URL(string: imageUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(themeManager.currentTheme.primaryColor.opacity(0.15))
                                    ProgressView()
                                }
                            }
                            .frame(width: 200, height: 200)
                            .cornerRadius(15)
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                        } else {
                            ZStack {
                                Circle()
                                    .fill(themeManager.currentTheme.primaryColor.opacity(0.15))
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "music.note")
                                    .font(.system(size: 40))
                                    .foregroundColor(themeManager.currentTheme.primaryColor)
                            }
                        }
                        
                        VStack(spacing: 8) {
                            Text(song.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                            
                            Text(song.artist)
                                .font(.title3)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15))
                    
                    // Links Section
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Linkler")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 10) {
                            if let spotifyLink = song.spotifyLink, !spotifyLink.isEmpty {
                                LinkButton(
                                    title: "Spotify'da Dinle",
                                    icon: "music.note",
                                    color: .green,
                                    url: spotifyLink
                                )
                            }
                            
                            if let appleMusicLink = song.appleMusicLink, !appleMusicLink.isEmpty {
                                LinkButton(
                                    title: "Apple Music'te Dinle",
                                    icon: "music.note.house",
                                    color: .red,
                                    url: appleMusicLink
                                )
                            }
                            
                            if let youtubeLink = song.youtubeLink, !youtubeLink.isEmpty {
                                LinkButton(
                                    title: "YouTube'da İzle",
                                    icon: "play.circle",
                                    color: .red,
                                    url: youtubeLink
                                )
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15))
                    
                    // Details Section
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Detaylar")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.secondary)
                                Text("Eklenme Tarihi")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            Text(song.date, formatter: DateFormatter.displayFormat)
                                .foregroundColor(.primary)
                                .padding(.leading, 20)
                            
                            if let note = song.note, !note.isEmpty {
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Image(systemName: "note.text")
                                            .foregroundColor(.secondary)
                                        Text("Not")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    Text(note)
                                        .foregroundColor(.primary)
                                        .padding(.leading, 20)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15))
                }
                .padding()
            }
            .navigationTitle("Şarkı Detayı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive, action: { showingDeleteAlert = true }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            .alert("Şarkıyı Sil", isPresented: $showingDeleteAlert) {
                Button("İptal", role: .cancel) {}
                Button("Sil", role: .destructive) {
                    Task {
                        try? await songService.deleteSong(song)
                        dismiss()
                    }
                }
            } message: {
                Text("Bu şarkıyı silmek istediğinizden emin misiniz?")
            }
        }
    }
}

// MARK: - Link Button
struct LinkButton: View {
    let title: String
    let icon: String
    let color: Color
    let url: String
    
    var body: some View {
        Button(action: {
            openURL(url)
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 24)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}
