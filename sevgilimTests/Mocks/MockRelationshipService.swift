//
//  MockRelationshipService.swift
//  sevgilimTests
//
//  RelationshipService mock for testing
//

import Foundation
import Combine
@testable import sevgilim

@MainActor
final class MockRelationshipService: ObservableObject {
    @Published var currentRelationship: Relationship?
    @Published var pendingInvitations: [PartnerInvitation] = []
    
    init(relationship: Relationship? = nil) {
        self.currentRelationship = relationship
    }
    
    func listenToRelationship(relationshipId: String) {
        // No-op
    }
    
    func stopListening() {
        // No-op
    }
}
