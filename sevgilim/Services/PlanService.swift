//
//  PlanService.swift
//  sevgilim
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
class PlanService: ObservableObject {
    @Published var plans: [Plan] = []
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    func listenToPlans(relationshipId: String) {
        listener?.remove()
        isLoading = true
        
        // Optimized query with limit
        listener = db.collection("plans")
            .whereField("relationshipId", isEqualTo: relationshipId)
            .order(by: "createdAt", descending: true)
            .limit(to: 50) // Limit to 50 plans
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error listening to plans: \(error.localizedDescription)")
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
                
                let newPlans = documents.compactMap { doc -> Plan? in
                    try? doc.data(as: Plan.self)
                }
                
                // Client-side sorting: En yeni oluşturulanlar üstte
                let sortedPlans = newPlans.sorted { $0.createdAt > $1.createdAt }
                
                Task { @MainActor in
                    self.plans = sortedPlans
                    self.isLoading = false
                }
            }
    }
    
    func addPlan(relationshipId: String, title: String, description: String?, 
                date: Date?, reminderEnabled: Bool, userId: String) async throws {
        var data: [String: Any] = [
            "relationshipId": relationshipId,
            "title": title,
            "description": description as Any,
            "isCompleted": false,
            "reminderEnabled": reminderEnabled,
            "createdBy": userId,
            "createdAt": Timestamp(date: Date())
        ]
        
        if let date = date {
            data["date"] = Timestamp(date: date)
        }
        
        try await db.collection("plans").addDocument(data: data)
    }
    
    func toggleCompletion(_ plan: Plan) async throws {
        guard let planId = plan.id else { return }
        
        let newStatus = !plan.isCompleted
        var updates: [String: Any] = ["isCompleted": newStatus]
        
        if newStatus {
            updates["completedAt"] = Timestamp(date: Date())
        } else {
            updates["completedAt"] = FieldValue.delete()
        }
        
        try await db.collection("plans").document(planId).updateData(updates)
    }
    
    func updatePlan(_ plan: Plan, title: String, description: String?, 
                   date: Date?, reminderEnabled: Bool) async throws {
        guard let planId = plan.id else { return }
        
        var updates: [String: Any] = [
            "title": title,
            "description": description as Any,
            "reminderEnabled": reminderEnabled
        ]
        
        if let date = date {
            updates["date"] = Timestamp(date: date)
        } else {
            updates["date"] = FieldValue.delete()
        }
        
        try await db.collection("plans").document(planId).updateData(updates)
    }
    
    func deletePlan(_ plan: Plan) async throws {
        guard let planId = plan.id else { return }
        try await db.collection("plans").document(planId).delete()
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    deinit {
        listener?.remove()
    }
}
