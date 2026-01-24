//
//  UserTests.swift
//  sevgilimTests
//
//  Unit tests for User model
//

import XCTest
@testable import sevgilim

final class UserTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testUser_hasCorrectProperties() {
        let createdAt = Date()
        let user = TestDataFactory.makeUser(
            id: "user-123",
            email: "test@example.com",
            name: "Test User",
            profileImageURL: "https://example.com/avatar.jpg",
            relationshipId: "rel-456",
            createdAt: createdAt
        )
        
        XCTAssertEqual(user.id, "user-123")
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertEqual(user.name, "Test User")
        XCTAssertEqual(user.profileImageURL, "https://example.com/avatar.jpg")
        XCTAssertEqual(user.relationshipId, "rel-456")
        XCTAssertEqual(user.createdAt, createdAt)
    }
    
    func testUser_withNilOptionals() {
        let user = TestDataFactory.makeUser(
            profileImageURL: nil,
            relationshipId: nil
        )
        
        XCTAssertNil(user.profileImageURL)
        XCTAssertNil(user.relationshipId)
    }
    
    func testUser_identifiable() {
        let user = TestDataFactory.makeUser(id: "unique-id")
        XCTAssertEqual(user.id, "unique-id")
    }
    
    func testUser_defaultFactory() {
        let user = TestDataFactory.makeUser()
        
        XCTAssertEqual(user.id, "test-user-1")
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertEqual(user.name, "Test User")
        XCTAssertEqual(user.relationshipId, "test-relationship-1")
    }
}
