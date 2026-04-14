//
//  MemoryService.swift
//  sevgilim
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
class MemoryService: ObservableObject {
    @Published var memories: [Memory] = []
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    private let decoder = Firestore.Decoder()
    private var listener: ListenerRegistration?
    private let offlineCache = OfflineDataManager.shared
    
    func listenToMemories(relationshipId: String) {
        listener?.remove()
        listener = nil
        isLoading = true
        
        // 🔥 Offline-first: Önce önbellekten yükle
        if let cachedMemories = offlineCache.loadMemories(), !cachedMemories.isEmpty {
            self.memories = cachedMemories
            self.isLoading = false
            print("⚡ MemoryService: \(cachedMemories.count) anı önbellekten yüklendi")
        }
        
        isLoading = memories.isEmpty // Sadece önbellek boşsa loading göster
        
        listener = db.collection("memories")
            .whereField("relationshipId", isEqualTo: relationshipId)
            .order(by: "date", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error listening to memories: \(error.localizedDescription)")
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
                
                // Process documents efficiently
                let newMemories = documents.compactMap { doc -> Memory? in
                    do {
                        var data = doc.data()
                        data["id"] = doc.documentID
                        return try self.decoder.decode(Memory.self, from: data)
                    } catch {
                        print("❌ Memory decode error for doc \(doc.documentID): \(error)")
                        return nil
                    }
                }
                
                Task { @MainActor in
                    self.memories = newMemories
                    self.isLoading = false
                    
                    // 💾 Önbelleğe kaydet
                    self.offlineCache.saveMemories(newMemories)
                    
                    // Anı fotoğraflarını önbelleğe al
                    let photoURLs = newMemories.flatMap { $0.allPhotoURLs }
                    if !photoURLs.isEmpty {
                        Task.detached(priority: .background) {
                            await ImageCacheService.shared.preloadImages(photoURLs, thumbnail: true)
                        }
                    }
                }
            }
    }
    
    func addMemory(relationshipId: String, title: String, content: String, 
                  date: Date, photoURLs: [String], location: String?, 
                  tags: [String]?, userId: String) async throws {
        var data: [String: Any] = [
            "relationshipId": relationshipId,
            "title": title,
            "content": content,
            "date": Timestamp(date: date),
            "photoURLs": photoURLs,
            "location": location as Any,
            "tags": tags as Any,
            "createdBy": userId,
            "createdAt": Timestamp(date: Date()),
            "likes": [],
            "comments": []
        ]
        
        // Geriye uyumluluk: İlk fotoğrafı photoURL olarak da kaydet
        if let firstPhoto = photoURLs.first {
            data["photoURL"] = firstPhoto
        }
        
        try await db.collection("memories").addDocument(data: data)
    }
    
    func updateMemory(_ memory: Memory,
                      title: String,
                      content: String,
                      date: Date,
                      photoURLs: [String],
                      removeAllPhotos: Bool,
                      location: String?,
                      tags: [String]?) async throws {
        guard let memoryId = memory.id else { return }
        
        var data: [String: Any] = [
            "title": title,
            "content": content,
            "date": Timestamp(date: date)
        ]
        
        let trimmedLocation = location?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmedLocation.isEmpty {
            data["location"] = FieldValue.delete()
        } else {
            data["location"] = trimmedLocation
        }
        
        if let tags = tags, !tags.isEmpty {
            data["tags"] = tags
        } else {
            data["tags"] = FieldValue.delete()
        }
        
        // Fotoğrafları güncelle
        if !photoURLs.isEmpty {
            data["photoURLs"] = photoURLs
            data["photoURL"] = photoURLs.first  // Geriye uyumluluk
        } else if removeAllPhotos {
            data["photoURLs"] = []
            data["photoURL"] = FieldValue.delete()
        }
        
        try await db.collection("memories").document(memoryId).updateData(data)
    }
    
    func toggleLike(memory: Memory, userId: String) async throws {
        guard let memoryId = memory.id else { return }
        
        var updatedLikes = memory.likes
        if updatedLikes.contains(userId) {
            updatedLikes.removeAll { $0 == userId }
        } else {
            updatedLikes.append(userId)
        }
        
        // Use optimistic update for better UX
        try await db.collection("memories").document(memoryId).updateData([
            "likes": updatedLikes
        ])
    }
    
    func addComment(memory: Memory, comment: Comment) async throws {
        guard let memoryId = memory.id else { return }
        
        var updatedComments = memory.comments
        updatedComments.append(comment)
        let commentsData = mapCommentsToData(updatedComments)
        
        try await db.collection("memories").document(memoryId).updateData([
            "comments": commentsData
        ])
    }
    
    func deleteComment(memory: Memory, comment: Comment) async throws {
        guard let memoryId = memory.id else { return }
        
        let updatedComments = memory.comments.filter { $0.id != comment.id }
        let commentsData = mapCommentsToData(updatedComments)
        
        try await db.collection("memories").document(memoryId).updateData([
            "comments": commentsData
        ])
    }
    
    private func mapCommentsToData(_ comments: [Comment]) -> [[String: Any]] {
        let commentsData = comments.map { comment in
            [
                "id": comment.id,
                "userId": comment.userId,
                "userName": comment.userName,
                "text": comment.text,
                "createdAt": Timestamp(date: comment.createdAt)
            ] as [String: Any]
        }
        
        return commentsData
    }
    
    func deleteMemory(_ memory: Memory) async throws {
        guard let memoryId = memory.id else { return }
        
        // Delete from Firestore first for immediate feedback
        try await db.collection("memories").document(memoryId).delete()
        
        // Delete all associated photos in background
        if !memory.photoURLs.isEmpty {
            Task.detached(priority: .background) {
                for photoURL in memory.photoURLs {
                    try? await StorageService.shared.deleteImage(url: photoURL)
                }
            }
        }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    deinit {
        listener?.remove()
    }
}
