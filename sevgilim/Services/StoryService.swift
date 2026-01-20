//
//  StoryService.swift
//  sevgilim
//

import Foundation
import Combine
import FirebaseFirestore
import FirebaseStorage
import UIKit
@preconcurrency import AVFoundation

@MainActor
class StoryService: ObservableObject {
    @Published var stories: [Story] = []
    @Published var userStories: [Story] = [] // Kullanıcının tüm story'leri
    @Published var partnerStories: [Story] = [] // Partner'ın tüm story'leri
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var listener: ListenerRegistration?
    
    // Story'leri dinle (real-time)
    func listenToStories(relationshipId: String, currentUserId: String) {
        listener?.remove()
        
        listener = db.collection("stories")
            .whereField("relationshipId", isEqualTo: relationshipId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Story dinleme hatası: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                // Story'leri parse et
                var fetchedStories: [Story] = []
                for doc in documents {
                    if let story = try? doc.data(as: Story.self) {
                        fetchedStories.append(story)
                    }
                }
                
                // Süresi dolmuşları sil (background task)
                for story in fetchedStories where story.isExpired {
                    Task {
                        try? await self.deleteStory(storyId: story.id ?? "")
                    }
                }
                
                // Aktif story'leri filtrele
                let activeStories = fetchedStories.filter { !$0.isExpired }
                
                DispatchQueue.main.async {
                    self.stories = activeStories
                    
                    // User ve partner story'lerini ayır (array olarak)
                    self.userStories = activeStories.filter { $0.createdBy == currentUserId }
                        .sorted { $0.createdAt < $1.createdAt } // Eskiden yeniye
                    self.partnerStories = activeStories.filter { $0.createdBy != currentUserId }
                        .sorted { $0.createdAt < $1.createdAt } // Eskiden yeniye
                }
            }
    }
    
    // Story yükle
    enum StoryUploadError: Error {
        case invalidMedia
        case mediaTooLarge
    }
    
    func uploadStory(
        relationshipId: String,
        userId: String,
        userName: String,
        userPhotoURL: String?,
        image: UIImage?,
        videoURL: URL?
    ) async throws -> Story {
        // Medya doğrulaması: ya fotoğraf ya video seçilmiş olmalı
        let hasImage = image != nil
        let hasVideo = videoURL != nil
        
        guard hasImage != hasVideo else {
            throw StoryUploadError.invalidMedia
        }
        
        let story: Story
        
        if let image = image {
            let optimizedImage = image.preparedForStoryUpload()

            // Fotoğraf upload
            let photoURL = try await uploadStoryImage(image: optimizedImage, relationshipId: relationshipId, userId: userId)
            let thumbnailURL = try? await uploadStoryThumbnail(image: optimizedImage, relationshipId: relationshipId, userId: userId)
            
            story = Story(
                photoURL: photoURL,
                thumbnailURL: thumbnailURL,
                mediaType: .photo,
                duration: nil,
                createdBy: userId,
                createdByName: userName,
                createdByPhotoURL: userPhotoURL,
                relationshipId: relationshipId,
                createdAt: Date(),
                viewedBy: [userId], // Oluşturan kişi otomatik görülmüş sayılır
                likedBy: [], // Başlangıçta beğeni yok
                likeTimestamps: [:]
            )
        } else if let videoURL = videoURL {
            // Video upload
            let videoResult = try await uploadStoryVideo(videoURL: videoURL, relationshipId: relationshipId, userId: userId)
            
            story = Story(
                photoURL: videoResult.downloadURL,
                thumbnailURL: videoResult.thumbnailURL,
                mediaType: .video,
                duration: videoResult.duration,
                createdBy: userId,
                createdByName: userName,
                createdByPhotoURL: userPhotoURL,
                relationshipId: relationshipId,
                createdAt: Date(),
                viewedBy: [userId],
                likedBy: [],
                likeTimestamps: [:]
            )
        } else {
            throw StoryUploadError.invalidMedia
        }
        
        // Firestore'a kaydet
        let docRef = try db.collection("stories").addDocument(from: story)
        
        var savedStory = story
        savedStory.id = docRef.documentID
        
        return savedStory
    }
    
    // Story fotoğrafını upload et
    private func uploadStoryImage(image: UIImage, relationshipId: String, userId: String) async throws -> String {
        // Resmi optimize et
        guard let imageData = image.jpegData(compressionQuality: 0.82) else {
            throw NSError(domain: "StoryService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Resim verisi oluşturulamadı"])
        }
        
        // Storage path
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "story_\(userId)_\(timestamp).jpg"
        let storagePath = "relationships/\(relationshipId)/stories/\(fileName)"
        let storageRef = storage.reference().child(storagePath)
        
        // Upload
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
        
        // Download URL al
        let downloadURL = try await storageRef.downloadURL()
        return downloadURL.absoluteString
    }
    
    // Story thumbnail'ı upload et
    private func uploadStoryThumbnail(image: UIImage, relationshipId: String, userId: String) async throws -> String {
        // Thumbnail boyutu (200x200)
        let thumbnailSize = CGSize(width: 200, height: 200)
        
        UIGraphicsBeginImageContextWithOptions(thumbnailSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: thumbnailSize))
        guard let thumbnail = UIGraphicsGetImageFromCurrentImageContext() else {
            UIGraphicsEndImageContext()
            throw NSError(domain: "StoryService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Thumbnail oluşturulamadı"])
        }
        UIGraphicsEndImageContext()
        
        guard let thumbnailData = thumbnail.jpegData(compressionQuality: 0.6) else {
            throw NSError(domain: "StoryService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Thumbnail verisi oluşturulamadı"])
        }
        
        // Storage path
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "story_thumb_\(userId)_\(timestamp).jpg"
        let storagePath = "relationships/\(relationshipId)/stories/thumbnails/\(fileName)"
        let storageRef = storage.reference().child(storagePath)
        
        // Upload
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await storageRef.putDataAsync(thumbnailData, metadata: metadata)
        
        // Download URL al
        let downloadURL = try await storageRef.downloadURL()
        return downloadURL.absoluteString
    }
    
    private func uploadStoryVideo(videoURL: URL, relationshipId: String, userId: String) async throws -> (downloadURL: String, thumbnailURL: String?, duration: Double?) {
        let sizeLimit = 50 * 1024 * 1024 // 50 MB
        let resourceValues = try videoURL.resourceValues(forKeys: [.fileSizeKey])
        if let fileSize = resourceValues.fileSize, fileSize > sizeLimit {
            throw StoryUploadError.mediaTooLarge
        }
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let ext = videoURL.pathExtension.lowercased()
        let resolvedExtension = ext.isEmpty ? "mov" : ext
        let fileName = "story_\(userId)_\(timestamp).\(resolvedExtension)"
        let storagePath = "relationships/\(relationshipId)/stories/videos/\(fileName)"
        let storageRef = storage.reference().child(storagePath)
        
        let metadata = StorageMetadata()
        metadata.contentType = contentType(forVideoExtension: resolvedExtension)
        
        _ = try await storageRef.putFileAsync(from: videoURL, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        
        let thumbnailImage = try await generateVideoThumbnail(url: videoURL)
        let thumbnailURL = try? await uploadStoryThumbnail(image: thumbnailImage, relationshipId: relationshipId, userId: userId)
        
        let asset = AVURLAsset(url: videoURL)
        let durationSeconds: Double
        if #available(iOS 16.0, *) {
             let duration = try await asset.load(.duration)
             durationSeconds = CMTimeGetSeconds(duration)
        } else {
             durationSeconds = CMTimeGetSeconds(asset.duration)
        }
        
        let duration = durationSeconds.isFinite ? durationSeconds : nil
        
        return (downloadURL.absoluteString, thumbnailURL, duration)
    }
    
    private func contentType(forVideoExtension ext: String) -> String {
        switch ext {
        case "mp4":
            return "video/mp4"
        case "mov":
            return "video/quicktime"
        case "m4v":
            return "video/x-m4v"
        default:
            return "video/mp4"
        }
    }
    
    private func generateVideoThumbnail(url: URL) async throws -> UIImage {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        
        if #available(iOS 16.0, *) {
            let (cgImage, _) = try await generator.image(at: time)
            return UIImage(cgImage: cgImage)
        } else {
            return try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                        let image = UIImage(cgImage: cgImage)
                        continuation.resume(returning: image)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    // Story'yi görüldü olarak işaretle
    func markStoryAsViewed(storyId: String, userId: String) async throws {
        let storyRef = db.collection("stories").document(storyId)
        
        // viewedBy array'ine ekle (duplicate kontrolü Firestore'da)
        try await storyRef.updateData([
            "viewedBy": FieldValue.arrayUnion([userId])
        ])
    }
    
    // Story sil
    func deleteStory(storyId: String) async throws {
        // Önce story'yi al (fotoğrafları silmek için)
        let storyRef = db.collection("stories").document(storyId)
        let document = try await storyRef.getDocument()
        
        if let story = try? document.data(as: Story.self) {
            // Storage'dan fotoğrafı sil
            if URL(string: story.photoURL) != nil {
                let photoRef = storage.reference(forURL: story.photoURL)
                try? await photoRef.delete()
            }
            
            // Thumbnail'ı sil
            if let thumbnailURL = story.thumbnailURL,
               URL(string: thumbnailURL) != nil {
                let thumbRef = storage.reference(forURL: thumbnailURL)
                try? await thumbRef.delete()
            }
        }
        
        // Firestore'dan sil
        try await storyRef.delete()
    }
    
    // Kullanıcının story'sini sil
    func deleteUserStory(userId: String) async throws {
        let userStories = userStories.filter { $0.createdBy == userId }
        for story in userStories {
            try await deleteStory(storyId: story.id ?? "")
        }
    }
    
    // Tüm süresi dolmuş story'leri sil
    func deleteExpiredStories(relationshipId: String) async throws {
        let snapshot = try await db.collection("stories")
            .whereField("relationshipId", isEqualTo: relationshipId)
            .getDocuments()
        
        for document in snapshot.documents {
            if let story = try? document.data(as: Story.self), story.isExpired {
                try await deleteStory(storyId: story.id ?? "")
            }
        }
    }
    
    // Story'yi beğen/beğenmekten vazgeç
    func toggleLike(storyId: String, userId: String) async throws {
        guard let docId = storyId as String? else { return }
        let storyRef = db.collection("stories").document(docId)
        
        // Mevcut story'yi al
        let document = try await storyRef.getDocument()
        guard var story = try? document.data(as: Story.self) else { return }
        
        // likedBy'ı initialize et (eski story'ler için)
        var currentLikedBy = story.likedBy ?? []
        var currentLikeTimestamps = story.likeTimestamps
        
        // Beğeni durumunu değiştir
        if currentLikedBy.contains(userId) {
            // Beğeniyi kaldır
            currentLikedBy.removeAll { $0 == userId }
            currentLikeTimestamps[userId] = nil
        } else {
            // Beğen
            currentLikedBy.append(userId)
            currentLikeTimestamps[userId] = Date()
        }
        
        // Firestore'u güncelle
        var updateData: [String: Any] = [
            "likedBy": currentLikedBy
        ]
        
        if currentLikeTimestamps.isEmpty {
            updateData["likeTimestamps"] = FieldValue.delete()
        } else {
            updateData["likeTimestamps"] = currentLikeTimestamps
        }
        
        try await storyRef.updateData(updateData)
    }
    
    // Listener'ı durdur
    func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    nonisolated deinit {
        // Direct removal in deinit - listener registration is thread-safe
    }
}
