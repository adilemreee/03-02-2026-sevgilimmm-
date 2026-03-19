//
//  SurpriseService.swift
//  sevgilim
//

import Foundation
import Combine
import FirebaseFirestore
import FirebaseStorage

@MainActor
class SurpriseService: ObservableObject {
    @Published var surprises: [Surprise] = []
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var listener: ListenerRegistration?
    
    func listenToSurprises(relationshipId: String, userId: String) {
        listener?.remove()
        listener = nil
        isLoading = true
        
        listener = db.collection("surprises")
            .whereField("relationshipId", isEqualTo: relationshipId)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error listening to surprises: \(error.localizedDescription)")
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
                
                let newSurprises = documents.compactMap { doc -> Surprise? in
                    try? doc.data(as: Surprise.self)
                }
                
                // Tarihe göre sırala: En yakın açılacak önce
                let sorted = newSurprises.sorted { $0.revealDate < $1.revealDate }
                
                Task { @MainActor in
                    self.surprises = sorted
                    self.isLoading = false
                }
            }
    }
    
    func addSurprise(
        relationshipId: String,
        createdBy: String,
        createdFor: String,
        title: String,
        message: String,
        revealDate: Date,
        image: UIImage?
    ) async throws {
        var photoURL: String? = nil
        
        // Fotoğraf yükleme
        if let image = image {
            photoURL = try await uploadSurpriseImage(image: image, relationshipId: relationshipId)
        }
        
        let surprise = Surprise(
            relationshipId: relationshipId,
            title: title,
            message: message,
            photoURL: photoURL,
            revealDate: revealDate,
            createdBy: createdBy,
            createdFor: createdFor,
            createdAt: Date(),
            isOpened: false,
            openedAt: nil,
            isManuallyHidden: false
        )
        
        try db.collection("surprises").addDocument(from: surprise)
        print("✅ Surprise added successfully")
    }
    
    func deleteSurprise(_ surprise: Surprise) async throws {
        guard let id = surprise.id else { return }
        
        // Eğer fotoğraf varsa Storage'dan da sil
        if let photoURL = surprise.photoURL {
            try? await deleteImageFromStorage(url: photoURL)
        }
        
        try await db.collection("surprises").document(id).delete()
        print("✅ Surprise deleted successfully")
    }
    
    func markAsOpened(_ surprise: Surprise) async throws {
        guard !surprise.isManuallyHidden else {
            print("⚠️ Surprise is manually hidden. Cannot mark as opened.")
            return
        }
        guard let id = surprise.id else { return }
        
        try await db.collection("surprises").document(id).updateData([
            "isOpened": true,
            "openedAt": Timestamp(date: Date()),
            "isManuallyHidden": false
        ])
        
        print("🎉 Surprise opened!")
    }
    
    func updateManualHiddenStatus(for surprise: Surprise, hidden: Bool) async throws {
        guard let id = surprise.id else { return }

        try await db.collection("surprises").document(id).updateData([
            "isManuallyHidden": hidden
        ])
        
        print(hidden ? "🔒 Surprise manually hidden." : "🔓 Surprise re-enabled.")
    }
    
    // MARK: - Storage Operations
    
    private func uploadSurpriseImage(image: UIImage, relationshipId: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "SurpriseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
        }
        
        let filename = UUID().uuidString + ".jpg"
        let storageRef = storage.reference().child("surprises/\(relationshipId)/\(filename)")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        
        return downloadURL.absoluteString
    }
    
    private func deleteImageFromStorage(url: String) async throws {
        let storageRef = storage.reference(forURL: url)
        try await storageRef.delete()
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    deinit {
        listener?.remove()
    }
    
    // MARK: - Helper Methods
    
    func surprisesCreatedByPartner(userId: String) -> [Surprise] {
        return surprises.filter { $0.createdFor == userId }
    }
    
    func surprisesCreatedByUser(userId: String) -> [Surprise] {
        return surprises.filter { $0.createdBy == userId }
    }
    
    func nextUpcomingSurpriseForUser(userId: String) -> Surprise? {
        return surprisesCreatedByPartner(userId: userId)
            .filter { $0.isLocked || $0.shouldReveal }
            .first
    }
}
