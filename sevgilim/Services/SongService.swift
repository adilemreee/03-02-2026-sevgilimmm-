//
//  SongService.swift
//  sevgilim
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
class SongService: ObservableObject {
    @Published var songs: [Song] = []
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private let songsLimit = 50 // Load first 50 songs for performance
    private let offlineCache = OfflineDataManager.shared
    
    func listenToSongs(relationshipId: String) {
        listener?.remove()
        isLoading = true
        
        // 🔥 Offline-first: Önce önbellekten yükle
        if let cachedSongs = offlineCache.loadSongs(), !cachedSongs.isEmpty {
            self.songs = cachedSongs
            self.isLoading = false
            print("⚡ SongService: \(cachedSongs.count) şarkı önbellekten yüklendi")
        }
        
        // Optimized query: limit results for faster loading
        listener = db.collection("songs")
            .whereField("relationshipId", isEqualTo: relationshipId)
            .order(by: "date", descending: true)
            .limit(to: songsLimit)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error listening to songs: \(error.localizedDescription)")
                    Task { @MainActor in
                        self.isLoading = false
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    Task { @MainActor in
                        self.isLoading = false
                    }
                    return
                }
                
                // Process only changed documents for better performance
                let newSongs = documents.compactMap { doc -> Song? in
                    try? doc.data(as: Song.self)
                }
                
                Task { @MainActor in
                    self.songs = newSongs
                    self.isLoading = false
                    
                    // 💾 Önbelleğe kaydet
                    self.offlineCache.saveSongs(newSongs)
                }
            }
    }
    
    func addSong(
        relationshipId: String,
        title: String,
        artist: String,
        imageUrl: String?,
        spotifyLink: String?,
        appleMusicLink: String?,
        youtubeLink: String?,
        note: String?,
        date: Date,
        userId: String
    ) async throws {
        let song = Song(
            relationshipId: relationshipId,
            title: title,
            artist: artist,
            imageUrl: imageUrl,
            spotifyLink: spotifyLink,
            appleMusicLink: appleMusicLink,
            youtubeLink: youtubeLink,
            note: note,
            addedBy: userId,
            date: date,
            createdAt: Date()
        )
        
        let _ = try db.collection("songs").addDocument(from: song)
    }
    
    func updateSong(_ song: Song) async throws {
        guard let id = song.id else { return }
        
        try db.collection("songs").document(id).setData(from: song)
    }
    
    func deleteSong(_ song: Song) async throws {
        guard let id = song.id else { return }
        
        try await db.collection("songs").document(id).delete()
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    deinit {
        listener?.remove()
        listener = nil
    }
}
