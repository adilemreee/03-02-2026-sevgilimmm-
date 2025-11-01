//
//  MoodService.swift
//  sevgilim
//

import Foundation
import FirebaseFirestore
import Combine

@MainActor
final class MoodService: ObservableObject {
    @Published private(set) var moodsByUser: [String: MoodStatus] = [:]
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    func listenToMoodStatuses(relationshipId: String) {
        listener?.remove()
        isLoading = true
        
        listener = db.collection("moodStatuses")
            .whereField("relationshipId", isEqualTo: relationshipId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                
                if let error {
                    print("❌ MoodService listen error: \(error.localizedDescription)")
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
                
                let statuses = documents.compactMap { doc in
                    try? doc.data(as: MoodStatus.self)
                }
                
                Task { @MainActor in
                    self.moodsByUser = statuses.reduce(into: [:]) { result, status in
                        result[status.userId] = status
                    }
                    self.isLoading = false
                }
            }
    }
    
    func setMood(relationshipId: String, userId: String, mood: MoodFeeling) async throws {
        let documentId = "\(relationshipId)_\(userId)"
        let now = Timestamp(date: Date())
        
        let data: [String: Any] = [
            "relationshipId": relationshipId,
            "userId": userId,
            "mood": mood.rawValue,
            "updatedAt": now
        ]
        
        try await db.collection("moodStatuses")
            .document(documentId)
            .setData(data, merge: true)
    }
    
    func mood(for userId: String) -> MoodStatus? {
        moodsByUser[userId]
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    deinit {
        listener?.remove()
    }
}
