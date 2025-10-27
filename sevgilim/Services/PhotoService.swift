//
//  PhotoService.swift
//  sevgilim
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
class PhotoService: ObservableObject {
    @Published var photos: [Photo] = []
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private let photosLimit = 50 // Load first 50 photos for performance
    
    func listenToPhotos(relationshipId: String) {
        listener?.remove()
        isLoading = true
        
        // Optimized query: limit results for faster loading
        listener = db.collection("photos")
            .whereField("relationshipId", isEqualTo: relationshipId)
            .order(by: "date", descending: true)
            .limit(to: photosLimit)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error listening to photos: \(error.localizedDescription)")
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
                let newPhotos = documents.compactMap { doc -> Photo? in
                    try? doc.data(as: Photo.self)
                }
                
                // Client-side sorting: En yeni tarihler üstte
                let sortedPhotos = newPhotos.sorted { $0.date > $1.date }
                
                Task { @MainActor in
                    self.photos = sortedPhotos
                    self.isLoading = false
                    
                    // Preload thumbnails for better UX
                    self.preloadThumbnails(photos: sortedPhotos)
                }
            }
    }
    
    // Preload images in cache for smooth scrolling
    private func preloadThumbnails(photos: [Photo]) {
        let urls = photos.prefix(10).map { $0.thumbnailURL ?? $0.imageURL }
        Task.detached(priority: .background) {
            await ImageCacheService.shared.preloadImages(Array(urls), thumbnail: true)
        }
    }
    
    func addPhoto(
        relationshipId: String,
        imageURL: String,
        thumbnailURL: String?,
        videoURL: String?,
        mediaType: PhotoMediaType,
        duration: Double?,
        title: String?,
        date: Date,
        location: String?,
        tags: [String]?,
        userId: String
    ) async throws {
        var data: [String: Any] = [
            "relationshipId": relationshipId,
            "imageURL": imageURL,
            "title": title as Any,
            "date": Timestamp(date: date),
            "location": location as Any,
            "tags": tags as Any,
            "uploadedBy": userId,
            "createdAt": Timestamp(date: Date()),
            "mediaType": mediaType.rawValue
        ]
        
        if let thumbnailURL {
            data["thumbnailURL"] = thumbnailURL
        }
        if let videoURL {
            data["videoURL"] = videoURL
        }
        if let duration {
            data["duration"] = duration
        }
        
        try await db.collection("photos").addDocument(data: data)
    }
    
    func deletePhoto(_ photo: Photo) async throws {
        guard let photoId = photo.id else { return }
        
        // Delete from storage (fire and forget for faster UX)
        Task.detached(priority: .background) {
            var urlsToDelete = Set<String>()
            urlsToDelete.insert(photo.imageURL)
            if let thumbnailURL = photo.thumbnailURL {
                urlsToDelete.insert(thumbnailURL)
            }
            if let videoURL = photo.videoURL {
                urlsToDelete.insert(videoURL)
            }
            
            for url in urlsToDelete {
                try? await StorageService.shared.deleteFile(at: url)
            }
        }
        
        // Delete from Firestore immediately
        try await db.collection("photos").document(photoId).delete()
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    deinit {
        listener?.remove()
    }
}
