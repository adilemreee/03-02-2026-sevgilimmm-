//
//  TreeGrowthService.swift
//  sevgilim
//
//  Created by Codex on 9.06.2024.
//

import Foundation
import Combine
import FirebaseFirestore

enum TreeWateringError: LocalizedError {
    case alreadyWateredToday
    case missingRelationship
    
    var errorDescription: String? {
        switch self {
        case .alreadyWateredToday:
            return "24 saat dolmadan yeniden sulayamazsınız."
        case .missingRelationship:
            return "İlişki bilgisi bulunamadı."
        }
    }
}

@MainActor
final class TreeGrowthService: ObservableObject {
    @Published var treeProgress: TreeProgress?
    @Published var isLoading = false
    @Published var isWatering = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var decayInProgress = false
    
    func listenToTreeProgress(relationshipId: String) {
        if let listener {
            listener.remove()
        }
        
        isLoading = true
        listener = db.collection("relationshipTrees")
            .document(relationshipId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                
                if let error {
                    print("❌ Tree listener error: \(error.localizedDescription)")
                    Task { @MainActor in
                        self.errorMessage = error.localizedDescription
                        self.isLoading = false
                    }
                    return
                }
                
                guard let snapshot else {
                    Task { @MainActor in
                        self.treeProgress = nil
                        self.isLoading = false
                    }
                    return
                }
                
                if !snapshot.exists {
                    Task { @MainActor in
                        self.treeProgress = nil
                        self.isLoading = false
                    }
                    return
                }
                
                if let data = snapshot.data(),
                   let progress = TreeProgress(id: snapshot.documentID, dictionary: data) {
                    Task { @MainActor in
                        self.treeProgress = progress
                        self.isLoading = false
                        self.applyDecayIfNeeded(for: progress, relationshipId: relationshipId)
                    }
                } else {
                    Task { @MainActor in
                        self.treeProgress = nil
                        self.errorMessage = "Aşk ağacı verileri çözümlenemedi."
                        self.isLoading = false
                    }
                }
            }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    func waterTree(relationshipId: String, userId: String) async throws {
        isWatering = true
        defer { isWatering = false }
        errorMessage = nil
        
        let document = db.collection("relationshipTrees").document(relationshipId)
        let now = Date()
        let snapshot = try await document.getDocument()
        
        if snapshot.exists {
            guard let data = snapshot.data(),
                  var progress = TreeProgress(id: snapshot.documentID, dictionary: data) else {
                throw TreeWateringError.missingRelationship
            }
            
            let elapsed = now.timeIntervalSince(progress.lastWateredAt)
            let minimumInterval: TimeInterval = 24 * 60 * 60
            
            if elapsed < minimumInterval {
                self.errorMessage = TreeWateringError.alreadyWateredToday.localizedDescription
                throw TreeWateringError.alreadyWateredToday
            }
            
            let dayGap = Int(elapsed / minimumInterval)
            
            if dayGap >= 2 {
                progress.consecutiveDays = 1
            } else {
                progress.consecutiveDays += 1
            }
            
            progress.totalWaterings += 1
            progress.lastWateredAt = now
            progress.updatedAt = now
            progress.lastWateredBy = userId
            
            let updates: [String: Any] = [
                "consecutiveDays": progress.consecutiveDays,
                "totalWaterings": progress.totalWaterings,
                "lastWateredAt": Timestamp(date: progress.lastWateredAt),
                "updatedAt": Timestamp(date: progress.updatedAt),
                "lastWateredBy": userId
            ]
            
            try await document.updateData(updates)
        } else {
            let newProgress = TreeProgress(
                id: document.documentID,
                relationshipId: relationshipId,
                consecutiveDays: 1,
                totalWaterings: 1,
                lastWateredAt: now,
                createdAt: now,
                updatedAt: now,
                lastWateredBy: userId
            )
            
            try await document.setData(newProgress.documentData)
        }
    }
    
    private func applyDecayIfNeeded(for progress: TreeProgress, relationshipId: String) {
        guard !decayInProgress else { return }
        
        let daysSince = progress.daysSinceLastWatering()
        if daysSince >= 2 && progress.consecutiveDays > 0 {
            decayInProgress = true
            Task {
                do {
                    try await resetStreak(for: progress, relationshipId: relationshipId)
                } catch {
                    print("❌ Tree decay update failed: \(error.localizedDescription)")
                }
                await MainActor.run {
                    self.decayInProgress = false
                }
            }
        }
    }
    
    private func resetStreak(for progress: TreeProgress, relationshipId: String) async throws {
        let document = db.collection("relationshipTrees").document(relationshipId)
        try await document.updateData([
            "consecutiveDays": 0,
            "updatedAt": Timestamp(date: Date())
        ])
    }
    
    deinit {
        listener?.remove()
    }
}
