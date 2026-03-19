//
//  RelationshipService.swift
//  sevgilim
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
class RelationshipService: ObservableObject {
    @Published var currentRelationship: Relationship?
    @Published var pendingInvitations: [PartnerInvitation] = []
    
    private let db = Firestore.firestore()
    private var relationshipListener: ListenerRegistration?
    private var invitationListener: ListenerRegistration?
    
    func sendInvitation(senderUserId: String, senderName: String, senderEmail: String, 
                       receiverEmail: String, startDate: Date) async throws {
        let invitation = PartnerInvitation(
            senderUserId: senderUserId,
            senderName: senderName,
            senderEmail: senderEmail,
            receiverEmail: receiverEmail,
            relationshipStartDate: startDate,
            status: .pending,
            createdAt: Date()
        )
        
        try await db.collection("invitations").addDocument(data: [
            "senderUserId": invitation.senderUserId,
            "senderName": invitation.senderName,
            "senderEmail": invitation.senderEmail,
            "receiverEmail": invitation.receiverEmail,
            "relationshipStartDate": Timestamp(date: invitation.relationshipStartDate),
            "status": invitation.status.rawValue,
            "createdAt": Timestamp(date: invitation.createdAt)
        ])
    }
    
    func listenForInvitations(userEmail: String) {
        invitationListener?.remove()
        
        invitationListener = db.collection("invitations")
            .whereField("receiverEmail", isEqualTo: userEmail)
            .whereField("status", isEqualTo: PartnerInvitation.InvitationStatus.pending.rawValue)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                self.pendingInvitations = documents.compactMap { doc in
                    let data = doc.data()
                    return PartnerInvitation(
                        id: doc.documentID,
                        senderUserId: data["senderUserId"] as? String ?? "",
                        senderName: data["senderName"] as? String ?? "",
                        senderEmail: data["senderEmail"] as? String ?? "",
                        receiverEmail: data["receiverEmail"] as? String ?? "",
                        relationshipStartDate: (data["relationshipStartDate"] as? Timestamp)?.dateValue() ?? Date(),
                        status: PartnerInvitation.InvitationStatus(rawValue: data["status"] as? String ?? "pending") ?? .pending,
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    )
                }
            }
    }
    
    func acceptInvitation(_ invitation: PartnerInvitation, receiverUserId: String, receiverName: String) async throws -> String {
        guard let invitationId = invitation.id else {
            throw NSError(
                domain: "RelationshipService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invitation ID is missing"]
            )
        }
        
        // Create relationship
        let relationshipRef = db.collection("relationships").document()
        
        try await relationshipRef.setData([
            "user1Id": invitation.senderUserId,
            "user2Id": receiverUserId,
            "user1Name": invitation.senderName,
            "user2Name": receiverName,
            "startDate": Timestamp(date: invitation.relationshipStartDate),
            "createdAt": Timestamp(date: Date()),
            "invitationId": invitationId
        ])
        
        // Update both users' relationshipId
        let batch = db.batch()
        batch.updateData(["relationshipId": relationshipRef.documentID], 
                        forDocument: db.collection("users").document(invitation.senderUserId))
        batch.updateData(["relationshipId": relationshipRef.documentID], 
                        forDocument: db.collection("users").document(receiverUserId))
        
        // Update invitation status
        batch.updateData([
            "status": PartnerInvitation.InvitationStatus.accepted.rawValue,
            "respondedAt": Timestamp(date: Date()),
            "relationshipId": relationshipRef.documentID
        ], forDocument: db.collection("invitations").document(invitationId))
        
        try await batch.commit()
        
        // Return the relationship ID
        return relationshipRef.documentID
    }
    
    func rejectInvitation(_ invitation: PartnerInvitation) async throws {
        guard let invitationId = invitation.id else { return }
        
        try await db.collection("invitations").document(invitationId).updateData([
            "status": PartnerInvitation.InvitationStatus.rejected.rawValue,
            "respondedAt": Timestamp(date: Date())
        ])
    }
    
    func listenToRelationship(relationshipId: String) {
        relationshipListener?.remove()
        
        relationshipListener = db.collection("relationships")
            .document(relationshipId)
            .addSnapshotListener { snapshot, error in
                guard let data = snapshot?.data() else { return }
                var chatClearedAt: [String: Date] = [:]
                if let clearedDict = data["chatClearedAt"] as? [String: Any] {
                    for (key, value) in clearedDict {
                        if let timestamp = value as? Timestamp {
                            chatClearedAt[key] = timestamp.dateValue()
                        }
                    }
                }
                
                self.currentRelationship = Relationship(
                    id: snapshot?.documentID,
                    user1Id: data["user1Id"] as? String ?? "",
                    user2Id: data["user2Id"] as? String ?? "",
                    user1Name: data["user1Name"] as? String ?? "",
                    user2Name: data["user2Name"] as? String ?? "",
                    startDate: (data["startDate"] as? Timestamp)?.dateValue() ?? Date(),
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                    themeColor: data["themeColor"] as? String,
                    chatClearedAt: chatClearedAt.isEmpty ? nil : chatClearedAt
                )
            }
    }
    
    func updateRelationship(startDate: Date?, themeColor: String?) async throws {
        guard let relationshipId = currentRelationship?.id else { return }
        
        var updates: [String: Any] = [:]
        if let startDate = startDate {
            updates["startDate"] = Timestamp(date: startDate)
        }
        if let themeColor = themeColor {
            updates["themeColor"] = themeColor
        }
        
        try await db.collection("relationships").document(relationshipId).updateData(updates)
    }
    
    func stopListening() {
        relationshipListener?.remove()
        relationshipListener = nil
        invitationListener?.remove()
        invitationListener = nil
    }
    
    deinit {
        relationshipListener?.remove()
        invitationListener?.remove()
    }
}
