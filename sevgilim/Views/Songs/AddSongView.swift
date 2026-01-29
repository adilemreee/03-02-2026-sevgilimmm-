//
//  AddSongView.swift
//  sevgilim
//

import SwiftUI

struct AddSongView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var songService: SongService
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var spotifyService = SpotifyService()
    
    @State private var title = ""
    @State private var artist = ""
    @State private var imageUrl = ""
    @State private var spotifyLink = ""
    @State private var appleMusicLink = ""
    @State private var youtubeLink = ""
    @State private var note = ""
    @State private var date = Date()
    @State private var isAdding = false
    @State private var searchText = ""
    @State private var selectedTrack: SpotifyTrack?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Gradient Background
                LinearGradient(
                    colors: [
                        themeManager.currentTheme.primaryColor.opacity(0.25),
                        themeManager.currentTheme.secondaryColor.opacity(0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        spotifySearchSection
                        selectedTrackSection
                        songInfoSection
                        noteSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Şarkı Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kaydet") {
                        addSong()
                    }
                    .disabled(title.isEmpty || artist.isEmpty || isAdding)
                }
            }
            .overlay {
                if isAdding {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 15) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Ekleniyor...")
                                .foregroundColor(.white)
                        }
                        .padding(30)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                    }
                }
            }
        }
    }
    
    // MARK: - Spotify Search Section
    @ViewBuilder
    private var spotifySearchSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "music.note.list")
                    .font(.headline)
                    .foregroundColor(.green)
                Text("Spotify'dan Şarkı Ara")
                    .font(.headline)
            }
            
            // Search Field
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("", text: $searchText, prompt: Text("Şarkı veya sanatçı ara..."))
                    .textFieldStyle(.plain)
                    .onChange(of: searchText) { _, newValue in
                        if !newValue.isEmpty {
                            Task {
                                await spotifyService.searchTracks(query: newValue)
                            }
                        } else {
                            spotifyService.clearSearch()
                        }
                    }
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        spotifyService.clearSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.94))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(themeManager.currentTheme.primaryColor.opacity(0.08), lineWidth: 1)
            )
            
            // Search Status
            if spotifyService.isSearching {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Aranıyor...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Search Results
            if !spotifyService.searchResults.isEmpty {
                VStack(spacing: 8) {
                    ForEach(spotifyService.searchResults.prefix(5)) { track in
                        SpotifyTrackRow(track: track) {
                            selectTrack(track)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 10)
    }
    
    // MARK: - Selected Track Section
    @ViewBuilder
    private var selectedTrackSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Seçilen Şarkı")
                .font(.headline)
            
            if let track = selectedTrack {
                HStack(spacing: 14) {
                    // Album Art
                    AsyncImage(url: URL(string: track.album.images.first?.url ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.2))
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.name)
                            .font(.headline)
                            .lineLimit(1)
                        
                        Text(track.artistNames)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Checkmark
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.green.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "music.quarternote.3")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Henüz şarkı seçilmedi")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Yukarıdan arayarak seçebilirsin")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemBackground).opacity(0.5))
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 10)
    }
    
    // MARK: - Song Info Section
    @ViewBuilder
    private var songInfoSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Şarkı Bilgileri")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                fieldLabel("Şarkı Adı")
                TextField("", text: $title, prompt: Text("Şarkı adını girin"))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(.systemBackground).opacity(0.94))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(themeManager.currentTheme.primaryColor.opacity(0.08), lineWidth: 1)
                    )
            }
            
            VStack(alignment: .leading, spacing: 12) {
                fieldLabel("Sanatçı")
                TextField("", text: $artist, prompt: Text("Sanatçı adını girin"))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(.systemBackground).opacity(0.94))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(themeManager.currentTheme.primaryColor.opacity(0.08), lineWidth: 1)
                    )
            }
            
            VStack(alignment: .leading, spacing: 12) {
                fieldLabel("Dinleme Tarihi")
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "tr_TR"))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.systemBackground).opacity(0.94))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(themeManager.currentTheme.primaryColor.opacity(0.08), lineWidth: 1)
                )
            }
            
            VStack(alignment: .leading, spacing: 12) {
                fieldLabel("Spotify Link (isteğe bağlı)")
                HStack(spacing: 12) {
                    Image(systemName: "link")
                        .foregroundColor(.green)
                    TextField("", text: $spotifyLink, prompt: Text("https://open.spotify.com/..."))
                        .textFieldStyle(.plain)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.systemBackground).opacity(0.94))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(themeManager.currentTheme.primaryColor.opacity(0.08), lineWidth: 1)
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 10)
    }
    
    // MARK: - Note Section
    @ViewBuilder
    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Not")
                .font(.headline)
            
            Text("Bu şarkı sizin için neden özel?")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ZStack(alignment: .topLeading) {
                if note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Şarkıyla ilgili anınızı yazın...")
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                }
                
                TextEditor(text: $note)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 100)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.94))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(themeManager.currentTheme.primaryColor.opacity(0.08), lineWidth: 1)
            )
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 10)
    }
    
    // MARK: - Helper Views
    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundColor(.secondary)
            .kerning(0.5)
    }
    
    // MARK: - Functions
    private func selectTrack(_ track: SpotifyTrack) {
        selectedTrack = track
        title = track.name
        artist = track.artistNames
        imageUrl = track.album.images.first?.url ?? ""
        spotifyLink = track.spotifyURL
        searchText = ""
        spotifyService.clearSearch()
    }
    
    private func addSong() {
        guard let userId = authService.currentUser?.id,
              let relationshipId = authService.currentUser?.relationshipId else { return }
        
        isAdding = true
        Task {
            do {
                try await songService.addSong(
                    relationshipId: relationshipId,
                    title: title,
                    artist: artist,
                    imageUrl: imageUrl.isEmpty ? nil : imageUrl,
                    spotifyLink: spotifyLink.isEmpty ? nil : spotifyLink,
                    appleMusicLink: appleMusicLink.isEmpty ? nil : appleMusicLink,
                    youtubeLink: youtubeLink.isEmpty ? nil : youtubeLink,
                    note: note.isEmpty ? nil : note,
                    date: date,
                    userId: userId
                )
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Error adding song: \(error)")
                await MainActor.run {
                    isAdding = false
                }
            }
        }
    }
}

// MARK: - Spotify Track Row
struct SpotifyTrackRow: View {
    let track: SpotifyTrack
    let onSelect: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: track.album.images.first?.url ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(track.artistNames)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundColor(.green)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.7))
            )
        }
        .buttonStyle(.plain)
    }
}
