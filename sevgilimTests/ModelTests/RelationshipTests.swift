//
//  RelationshipTests.swift
//  sevgilimTests
//
//  Unit tests for Relationship model methods
//

import XCTest
@testable import sevgilim

final class RelationshipTests: XCTestCase {
    
    // MARK: - partnerName() Tests
    
    func testPartnerName_forUser1_returnsUser2Name() {
        let relationship = TestDataFactory.makeRelationship(
            user1Id: "user-1",
            user2Id: "user-2",
            user1Name: "Adil",
            user2Name: "Emre"
        )
        
        XCTAssertEqual(relationship.partnerName(for: "user-1"), "Emre")
    }
    
    func testPartnerName_forUser2_returnsUser1Name() {
        let relationship = TestDataFactory.makeRelationship(
            user1Id: "user-1",
            user2Id: "user-2",
            user1Name: "Adil",
            user2Name: "Emre"
        )
        
        XCTAssertEqual(relationship.partnerName(for: "user-2"), "Adil")
    }
    
    func testPartnerName_forUnknownUser_returnsUser1Name() {
        // When userId doesn't match user1Id, it defaults to user1Name
        let relationship = TestDataFactory.makeRelationship(
            user1Id: "user-1",
            user2Id: "user-2",
            user1Name: "Adil",
            user2Name: "Emre"
        )
        
        XCTAssertEqual(relationship.partnerName(for: "unknown-user"), "Adil")
    }
    
    // MARK: - partnerId() Tests
    
    func testPartnerId_forUser1_returnsUser2Id() {
        let relationship = TestDataFactory.makeRelationship(
            user1Id: "user-1",
            user2Id: "user-2"
        )
        
        XCTAssertEqual(relationship.partnerId(for: "user-1"), "user-2")
    }
    
    func testPartnerId_forUser2_returnsUser1Id() {
        let relationship = TestDataFactory.makeRelationship(
            user1Id: "user-1",
            user2Id: "user-2"
        )
        
        XCTAssertEqual(relationship.partnerId(for: "user-2"), "user-1")
    }
    
    // MARK: - Initialization Tests
    
    func testRelationship_hasCorrectProperties() {
        let startDate = Date().addingTimeInterval(-86400 * 100)
        let relationship = TestDataFactory.makeRelationship(
            id: "rel-123",
            user1Id: "u1",
            user2Id: "u2",
            user1Name: "Alice",
            user2Name: "Bob",
            startDate: startDate
        )
        
        XCTAssertEqual(relationship.id, "rel-123")
        XCTAssertEqual(relationship.user1Id, "u1")
        XCTAssertEqual(relationship.user2Id, "u2")
        XCTAssertEqual(relationship.user1Name, "Alice")
        XCTAssertEqual(relationship.user2Name, "Bob")
        XCTAssertEqual(relationship.startDate, startDate)
    }
}
