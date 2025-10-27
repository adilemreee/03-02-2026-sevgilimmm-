//
//  SecretVaultService.swift
//  sevgilim
//

import Foundation
import FirebaseFirestore
import FirebaseStorage
import Combine

@MainActor
final class SecretVaultService: ObservableObject {
    @Published private(set) var items: [SecretVaultItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var listener: ListenerRegistration?
    
    private var collection: CollectionReference {
        db.collection("secretVault")
    }
    
    func listenToVault(relationshipId: String) {
        listener?.remove()
        isLoading = true
        errorMessage = nil
        
        listener = collection
            .whereField("relationshipId", isEqualTo: relationshipId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                
                if let error {
                    Task { @MainActor in
                        self.errorMessage = error.localizedDescription
                        self.isLoading = false
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    Task { @MainActor in
                        self.items = []
                        self.isLoading = false
                    }
                    return
                }
                
                let fetched: [SecretVaultItem] = documents.compactMap { doc in
                    do {
                        return try doc.data(as: SecretVaultItem.self)
                    } catch {
                        print("❌ SecretVault decode error: \(error.localizedDescription)")
                        return nil
                    }
                }
                
                Task { @MainActor in
                    self.items = fetched
                    self.isLoading = false
                }
            }
    }
    
    func addMedia(
        relationshipId: String,
        downloadURL: String,
        thumbnailURL: String?,
        storagePath: String,
        thumbnailPath: String?,
        type: SecretMediaType,
        title: String?,
        note: String?,
        uploadedBy: String,
        sizeInBytes: Int64?,
        duration: Double?,
        contentType: String
    ) async throws {
        var data: [String: Any] = [
            "relationshipId": relationshipId,
            "downloadURL": downloadURL,
            "thumbnailURL": thumbnailURL as Any,
            "storagePath": storagePath,
            "thumbnailPath": thumbnailPath as Any,
            "type": type.rawValue,
            "uploadedBy": uploadedBy,
            "createdAt": Timestamp(date: Date()),
            "sizeInBytes": sizeInBytes as Any,
            "duration": duration as Any,
            "contentType": contentType
        ]
        
        if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            data["title"] = title
        }
        
        if let note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            data["note"] = note
        }
        
        try await collection.addDocument(data: data)
    }
    
    func delete(_ item: SecretVaultItem) async throws {
        guard let id = item.id else { return }
        
        // Delete Firestore document first for snappy UX
        try await collection.document(id).delete()
        
        Task.detached { [storage] in
            do {
                let fileRef = storage.reference(forURL: item.downloadURL)
                try await fileRef.delete()
            } catch {
                print("❌ SecretVault storage delete error (media): \(error.localizedDescription)")
            }
            
            if let thumbURL = item.thumbnailURL {
                do {
                    let thumbRef = storage.reference(forURL: thumbURL)
                    try await thumbRef.delete()
                } catch {
                    print("ℹ️ SecretVault thumbnail delete failed: \(error.localizedDescription)")
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
